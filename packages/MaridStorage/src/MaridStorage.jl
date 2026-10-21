# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridStorage

Persistence seam for Marid.

What exists: `InMemoryEngine`, a test double. That is all.

What does NOT exist, despite earlier claims in this docstring and in the package
README: SQLite, DuckDB, and a real ArangoDB backend. `ArangoStorageEngine` is a
seam with no client behind it and now refuses to run unless explicitly marked as
a mock (recon-2026-10-21, C05). `PROJECT_BRIEF.md` §2 requires the memory engine
to be described as test storage and requires real container-backed tests before
any backend is called supported.
"""
module MaridStorage

using Dates
using UUIDs

export StorageEngine, InMemoryEngine, ArangoStorageEngine, is_mock,
       put_entity!, get_entity, delete_entity!, query_entities

abstract type StorageEngine end

struct InMemoryEngine <: StorageEngine
    records::Dict{String, Dict{String, Any}}
end

InMemoryEngine() = InMemoryEngine(Dict{String, Dict{String, Any}}())

function put_entity!(engine::InMemoryEngine, collection::String, id::String, data::Dict{String, Any})
    key = "$collection/$id"
    engine.records[key] = copy(data)
    engine.records[key]["_id"] = key
    return engine.records[key]
end

function get_entity(engine::InMemoryEngine, collection::String, id::String)
    key = "$collection/$id"
    record = get(engine.records, key, nothing)
    # Copy on read: handing out the stored dictionary let a caller mutate the
    # store without going through put_entity!, and made "engine" semantics a lie
    # (recon-2026-10-21, P14).
    return record === nothing ? nothing : copy(record)
end

function delete_entity!(engine::InMemoryEngine, collection::String, id::String)
    key = "$collection/$id"
    return delete!(engine.records, key)
end

function query_entities(engine::InMemoryEngine, collection::String; filter_fn::Function = x -> true)
    prefix = "$collection/"
    results = Dict{String, Any}[]
    for (k, v) in engine.records
        if startswith(k, prefix) && filter_fn(v)
            push!(results, copy(v))
        end
    end
    return results
end

"""
    ArangoStorageEngine(endpoint, database; mock=false)

ArangoDB storage seam.

There is NO ArangoDB client behind this type yet: `packages/MaridArango` is an
in-memory double (recon-2026-10-21, C04) and this adapter used to forward every
operation to `in_memory_fallback` silently. That is the worst possible failure
mode for a persistence seam — a caller configures a real endpoint, every write
succeeds, and the data is gone after a restart with no warning anywhere.

So the fallback is now opt-in and loud:

* `mock=false` (default): every operation throws `ArgumentError` naming itself as
  unimplemented. A deployment that reaches this code fails at the first write
  instead of losing data quietly.
* `mock=true`: explicit test double. Only tests may construct it this way, and
  `is_mock(engine)` lets a test assert that it did.

`PROJECT_BRIEF.md` §2 and the recovery plan's work package E require a real
HTTP client, revision preconditions, cursors and transactions before this type
can be called an ArangoDB backend.
"""
struct ArangoStorageEngine <: StorageEngine
    endpoint::String
    database::String
    in_memory_fallback::InMemoryEngine
    mock::Bool
end

ArangoStorageEngine(endpoint::String="http://127.0.0.1:8529", database::String="_system"; mock::Bool=false) =
    ArangoStorageEngine(endpoint, database, InMemoryEngine(), mock)

"True only for an explicitly constructed test double."
is_mock(engine::ArangoStorageEngine)::Bool = engine.mock

function _require_mock(engine::ArangoStorageEngine, operation::AbstractString)
    engine.mock || throw(ArgumentError(
        "ArangoStorageEngine.$operation is not implemented: no ArangoDB client is wired into MaridStorage. " *
        "Construct the engine with mock=true only in tests. See docs/audits/recon-2026-10-21.adoc (C05)."))
    return nothing
end

function put_entity!(engine::ArangoStorageEngine, collection::String, id::String, data::Dict{String, Any})
    _require_mock(engine, "put_entity!")
    put_entity!(engine.in_memory_fallback, collection, id, data)
end

function get_entity(engine::ArangoStorageEngine, collection::String, id::String)
    _require_mock(engine, "get_entity")
    get_entity(engine.in_memory_fallback, collection, id)
end

function delete_entity!(engine::ArangoStorageEngine, collection::String, id::String)
    _require_mock(engine, "delete_entity!")
    delete_entity!(engine.in_memory_fallback, collection, id)
end

function query_entities(engine::ArangoStorageEngine, collection::String; filter_fn::Function = x -> true)
    _require_mock(engine, "query_entities")
    query_entities(engine.in_memory_fallback, collection; filter_fn=filter_fn)
end

end # module MaridStorage
