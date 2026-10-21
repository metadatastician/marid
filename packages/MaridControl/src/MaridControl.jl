# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridControl

Control plane for Marid:
- Versioned immutable snapshots with lock-free atomic swaps.
- Append-only sequence log abstraction.
- Control plane backend seam (etcd/Consul abstraction) with changefeeds.
- Control-plane-down isolation: request serving operates entirely from local snapshots,
  guaranteeing zero control plane contention on the request path.
"""
module MaridControl

using Dates
using UUIDs

export Snapshot, AtomicConfig, get_snapshot, swap_snapshot!, update_snapshot!,
       LogEntry, SequentialLog, append_log!, read_log_from,
       ControlBackend, InMemoryControlBackend,
       ControlNode, serve_request, sync_from_backend!, set_connected!

# 1. Versioned Immutable Snapshot
struct Snapshot
    version::UInt64
    timestamp::DateTime
    data::Dict{String, Any}
end

Snapshot(version::Integer=0) = Snapshot(UInt64(version), now(UTC), Dict{String, Any}())

# 2. Atomic Configuration Container
# Provides lock-free / low-contention pointer swap
mutable struct AtomicConfig
    @atomic current::Snapshot
    AtomicConfig(snap::Snapshot) = new(snap)
end

AtomicConfig() = AtomicConfig(Snapshot(0))

function get_snapshot(cfg::AtomicConfig)::Snapshot
    return @atomic cfg.current
end

"""
    swap_snapshot!(cfg::AtomicConfig, next::Snapshot) -> Snapshot

Install `next` as the current snapshot and return it, mirroring
`update_snapshot!` (which also returns the snapshot it installed).

This is an *unconditional* swap: it is the caller's decision to replace the
configuration, so there is nothing to compare against and nothing that can fail.
An earlier version used `@atomicreplace cfg.current cfg.current => next`, which
takes a separate read and replace: a concurrent `update_snapshot!` or another
swap landing between them makes `success` false and the call throws. The
setup here ("lock-free swaps with concurrent readers and writers") makes that
interleaving reachable, so the compare-and-swap was the wrong primitive.

History that keeps this honest: the original `@atomicreplace` version returned a
`NamedTuple{(:old, :success)}` where `::Snapshot` was annotated, so the function
threw `MethodError` on every call and nothing noticed
(`docs/audits/recon-2026-10-21.adoc`, C03). The fix kept the `@atomicreplace`
shape; a plain atomic store is simpler and cannot fail.
"""
function swap_snapshot!(cfg::AtomicConfig, next::Snapshot)::Snapshot
    @atomic cfg.current = next
    return next
end

function update_snapshot!(mutator::Function, cfg::AtomicConfig)::Snapshot
    while true
        old = @atomic cfg.current
        new_data = mutator(copy(old.data))
        new_snap = Snapshot(old.version + 1, now(UTC), new_data)
        res = @atomicreplace cfg.current old => new_snap
        if res.success
            return new_snap
        end
    end
end

update_snapshot!(cfg::AtomicConfig, mutator::Function)::Snapshot = update_snapshot!(mutator, cfg)

# 3. Append-Only Sequential Log
struct LogEntry
    index::UInt64
    term::UInt64
    key::String
    value::Any
    timestamp::DateTime
end

mutable struct SequentialLog
    entries::Vector{LogEntry}
    lock::ReentrantLock
end

SequentialLog() = SequentialLog(LogEntry[], ReentrantLock())

function append_log!(log::SequentialLog, term::Integer, key::String, value::Any)::LogEntry
    lock(log.lock) do
        idx = UInt64(length(log.entries) + 1)
        entry = LogEntry(idx, UInt64(term), key, value, now(UTC))
        push!(log.entries, entry)
        return entry
    end
end

function read_log_from(log::SequentialLog, start_index::Integer)::Vector{LogEntry}
    lock(log.lock) do
        idx = max(1, Int(start_index))
        idx > length(log.entries) && return LogEntry[]
        return copy(log.entries[idx:end])
    end
end

# 4. Control Plane Backend Seam
abstract type ControlBackend end

mutable struct InMemoryControlBackend <: ControlBackend
    store::Dict{String, Any}
    is_connected::Bool
    change_subscribers::Vector{Channel{Dict{String, Any}}}
    lock::ReentrantLock
end

InMemoryControlBackend() = InMemoryControlBackend(Dict{String, Any}(), true, Channel{Dict{String, Any}}[], ReentrantLock())

function set_connected!(backend::InMemoryControlBackend, connected::Bool)
    lock(backend.lock) do
        backend.is_connected = connected
    end
end

function put_key!(backend::InMemoryControlBackend, key::String, val::Any)
    lock(backend.lock) do
        !backend.is_connected && error("Control plane unreachable (disconnected)")
        backend.store[key] = val
        for ch in backend.change_subscribers
            if isopen(ch)
                put!(ch, Dict{String, Any}("key" => key, "value" => val))
            end
        end
    end
end

# 5. Control Node with Control-Plane-Down Isolation
mutable struct ControlNode
    config::AtomicConfig
    backend::ControlBackend
    log::SequentialLog
end

function ControlNode(backend::ControlBackend = InMemoryControlBackend())
    node = ControlNode(AtomicConfig(Snapshot(0)), backend, SequentialLog())
    return node
end

"""
    serve_request(node::ControlNode, key::String) -> Any

Serves traffic exclusively from the local snapshot.
Never blocks on, nor reaches out to, the control plane backend.
"""
function serve_request(node::ControlNode, key::String)
    snap = get_snapshot(node.config)
    return get(snap.data, key, nothing)
end

"""
    sync_from_backend!(node::ControlNode)

Updates local state from control plane backend when connected.
Performs an atomic swap to update live traffic with zero request lock contention.
"""
function sync_from_backend!(node::ControlNode, updates::Dict{String, Any})
    update_snapshot!(node.config) do data
        merge!(data, updates)
        return data
    end
end

end # module MaridControl
