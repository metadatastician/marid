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

`@atomicreplace` returns a `NamedTuple{(:old, :success)}`, not a `Snapshot`;
annotating this function `::Snapshot` therefore made the previous definition
throw `MethodError: Cannot convert ... to Snapshot` on EVERY call, and the
absence of a test is why it survived from 2026-09-19 to this change
(`docs/audits/recon-2026-10-21.adoc`, C03). The compare-and-swap below reads and
replaces the same value, so it always succeeds; `success` is asserted rather
than assumed so a future change to the atomic cannot silently return the wrong
snapshot.
"""
function swap_snapshot!(cfg::AtomicConfig, next::Snapshot)::Snapshot
    res = @atomicreplace cfg.current cfg.current => next
    res.success || error("snapshot swap failed unexpectedly")
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
