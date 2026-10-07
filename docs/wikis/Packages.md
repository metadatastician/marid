<!-- berrywiki
id: 01a115aa-ca20-839a-9249-dc444367c78d
parent: 01a115aa-ca16-8134-837f-254d19a045bf
position: 30
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Packages

The thirteen Julia packages under `packages/`, grouped by charter phase. Each has its own `Project.toml`, test suite and README; `packages/README.adoc` is the in-repo index. The monorepo is the canonical source for every package (D53, ruled 2026-09-22); the former standalone satellite repositories are covered on [[Ecosystem]].

Back to [[Home]].

## Status words

Per AGENTS.md §6 the words below are distinct and none implies the next: **implemented** (source exists), **tested** (its own suite passes locally), **proved** (independent interop or real-network evidence), **deployed**. Every package below is implemented and tested. Only the launch-set HTTP/JSON slice has any proved evidence (see [[Evidence]]). Nothing is deployed and nothing is registered in Julia General.

## Launch set (Phase 1)

| Package | Purpose | Deps | Notes |
|---|---|---|---|
| **MaridIR** | `ServiceDescriptor`, `MethodDescriptor`, `TypeRef`, streaming modes, annotations. Pure data plus validation. Emits the gateway Verb Governance Spec (`emit_capability_spec`). | none | The single source of truth for every artifact. 21 + 58 assertions pass. |
| **MaridCodec** | Codec seam; content negotiation (Accept, q-values, Vary); JSON via JSON3; MsgPack/CBOR as extensions. | JSON3 | 4 + 12 assertions. |
| **MaridOpenAPI** | IR → OpenAPI 3.1 + JSON Schema 2020-12. | MaridIR | Path merging and component emission still listed as work in `docs/plans/charter-recovery-and-next-steps.adoc` C1. |
| **MaridRPC** | JSON-RPC 2.0 + MCP adapter over the IR; SSE transport hook. | MaridIR, MaridCodec | Real JSON-RPC error codes (`dispatch_rpc`). |
| **MaridGraphQL** | IR → GraphQL SDL + introspection first; resolver runtime later. | MaridIR | Execution is a stub per the 2026-09-19 recon. |

## Core (Phase 2)

| Package | Purpose | Notes |
|---|---|---|
| **MaridTransport** | Transport seam; HTTP/1.1 (HTTP.jl), SSE, WebSocket upgrade, chunked/trailers. | 29 assertions. Real socket listener exercised by `examples/http_json`. |
| **MaridCore** | Router (trie, tuple key), middleware `f(call, next)`, `CallContext`, server assembly. Extension `MaridHTTPJSONExt` binds HTTP/JSON. | Precompile blocker (misplaced docstring, marid#37) fixed in PR #39. marid#40 asks for a CI gate asserting every package precompiles. |

## Storage (Phase 3)

| Package | Purpose | Notes |
|---|---|---|
| **MaridArango** | Native Julia HTTP client for ArangoDB: auth, pooling, cursors, AQL, transactions, retries, changefeeds. Stdlib-only deps. | Renamed from `ArangoDB` on 2026-09-22 (D57); UUID `01a115ae-6523-8273-8497-753822252d6a` kept. The recon found the client's HTTP path mocked; real-container tests are work package E. |
| **MaridStorage** | Storage seam; in-memory, SQLite and DuckDB implementations; Arango via package extension. | Silent fallback to memory when the database is unavailable is a recorded defect to remove. |

## Later (Phases 4–7)

| Package | Purpose | Gate |
|---|---|---|
| **MaridControl** | Snapshot / atomic swap, log abstraction, etcd/Consul backend, changefeed invalidation. | after Core works |
| **MaridLive** | HTMX / Turbo / Datastar helpers over SSE and WS. | after Transport |
| **MaridCRDT** | LWW-Register, OR-Set, G/PN-Counter, presence. | after Control |
| **MaridRaft** | Own Raft (elections, log, compaction, membership). | last; may never be needed if etcd suffices |

## Dependency rules

- Standalone adapters (`MaridArango`, `MaridCodec`, `MaridRPC`) must load without `MaridCore`.
- Intra-family dependencies resolve in-tree through `path =` entries in each committed `Manifest.toml`. This is why the standalone satellite copies could never pass CI on their own (their manifests pointed at `../X.jl` siblings that exist only on the authoring machine).
- Every dep and weakdep carries an upper-bounded `[compat]` entry, stdlibs included. `scripts/check-julia-compat.jl` enforces this in the `cli-and-emitters` CI job (D68, marid#22, PR #34). It is deliberately stricter than Julia General AutoMerge; do not loosen it to match.

## Registration

D117 targets Tier-1 Julia General registration by **2026-10-14**. Prerequisites: a green `main`, the marid#40 precompile gate, `bun test` over `web/`, and the still-open owner rulings listed on [[Roadmap]]. UUIDs and names are immutable after registration, so D55 ruled that the whole family submits as one coherent set after the D56/D57 renames (both done 2026-09-22). Submission order once it starts: the nine zero-dep packages in parallel, then the four dependents (MaridCore, MaridGraphQL, MaridOpenAPI, MaridRPC), then `RelationshipExplorer`.

## Examples

- `examples/http_json`: The live unary HTTP/JSON slice (30 + 8 assertions) that proves IR → router → codec on a real socket.
- `examples/relationship_explorer`: The reference application. In-memory today; the brief requires it to exercise persistence, every adapter and a real browser before Gate 4 closes. Its package `RelationshipExplorer` had four registration blockers (placeholder UUID, `[package]` table, name mismatch, unregistered dep), all fixed 2026-09-22 under D56.

## Known stale statements in the sources

- `packages/README.adoc` marks all 13 packages "Implemented & Passing". True for local unit suites only; it is not release acceptance.
- `docs/marid-roadmap.adoc` and `docs/FRAMEWORK-ALIGNMENT.adoc` still name `packages/ArangoDB/`. Read as `packages/MaridArango/`.
- The charter's phase tables name `ArangoDB.jl`; same rename.

## Related pages

[[Architecture]] · [[Web-SDKs]] · [[Evidence]] · [[Roadmap]] · [[Ecosystem]]
