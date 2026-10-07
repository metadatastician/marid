<!-- berrywiki
id: 01a115aa-ca1d-862c-a602-a6ba2aa9bc8d
parent: 01a115aa-ca16-8134-837f-254d19a045bf
position: 20
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Architecture

How a request moves through Marid, which invariants hold at each layer, and the six contracts every package honours. Canonical sources: `docs/marid-architecture.adoc` (reconciled at Gate 0), `docs/marid-compatibility.adoc`, `docs/architecture/TOPOLOGY.adoc`, `docs/architecture/THREAT-MODEL.adoc` and `docs/architecture/REPOSITORY-MAP.adoc` (generated; do not hand-edit).

Back to [[Home]].

## Four orthogonal layers

1. **Intermediate Representation (IR).** Pure service, method and streaming descriptions. `MaridIR`.
2. **Protocol adapters and codecs.** Standalone modules translating native protocols to and from the IR. `MaridOpenAPI`, `MaridRPC`, `MaridGraphQL`, `MaridCodec`.
3. **Core data plane.** Pure trie routing, streaming middleware pipeline, `CallContext`. `MaridTransport`, `MaridCore`.
4. **Pluggable persistence.** Abstract storage seam, with ArangoDB for production graph/document workloads. `MaridStorage`, `MaridArango`.

The package-by-package view is on [[Packages]].

## The request pipeline

```
Incoming wire request (HTTP/1.1 · SSE · WebSocket · RPC)
        │
        ▼
  MaridTransport      decode frames, parse headers, upgrade sockets
        │
        ▼
  MaridCore router    pure lookup (method, path) → handler
        │             reads an immutable local RouteTable snapshot: no network, no locks
        ▼
  Middleware          f(ctx, call, next); establishes CallContext
        │             (principal, tenant, deadline, trace)
        ▼
  Handler             (ctx::CallContext, input::Stream{I}) -> Stream{O}
        │
        ▼
  MaridCodec          content negotiation (Accept, q=, Vary); JSON3, CBOR, MsgPack, …
        │
        ▼
  Storage seam        MaridStorage → in-memory · SQLite · DuckDB · MaridArango
```

The control plane (`MaridControl`) sits beside this path, never on it. It publishes a new RouteTable by atomic swap; etcd/Consul or Arango changefeeds feed invalidation.

## Invariants

- The router never blocks and never allocates locks.
- Nodes keep serving traffic with the control plane down.
- Arango is never on the route-lookup path.
- No Julia `eval`, `Meta.parse` or unsafe deserialization of untrusted network input, ever.
- No global singleton holds user or tenant state.

## The six core contracts

| Contract | Normative design |
|---|---|
| **CallContext** | Immutable request-scoped record: `principal`, `tenant_scope`, `deadline` (monotonic `time_ns()`), `cancellation` (`Base.Event`), `trace_id` (W3C Trace Context). |
| **Service interfaces** | `handler(ctx::CallContext, input::Stream{I})::Stream{O}`. Handlers have zero awareness of transport. |
| **Streaming and flow control** | Bounded `Channel{T}(capacity)`; slow consumers get backpressure; client disconnect triggers `notify(ctx.cancellation)`. |
| **Domain errors** | Stable exceptions extending `MaridError`. HTTP maps to RFC 9457 Problem Details; GraphQL to `errors` with path and extensions; gRPC to canonical status codes. |
| **Data ownership** | Decoded request values belong to the handler; borrowed buffer slices must be copied before async use beyond the handler. |
| **Persistence and transactions** | Explicit cursor lifecycle; concurrency via `_rev` revision checks; retries only on demonstrably idempotent reads. |

## Supported toolchains

| Component | Supported | Notes |
|---|---|---|
| Julia | 1.10 LTS and 1.11 | Backend packages. CI matrix runs both on Ubuntu. |
| Browser runtime | Bun 1.1+ | `web/` packages. Node, npm and Deno are ejected. |
| Browser language | AffineScript 0.2+ | `.affine` → typed WebAssembly via `@hyperpolymath/affinescript`. TypeScript is forbidden by estate policy. AffineScript 0.2 is experimental; the toolchain remains a Gate 0 feasibility blocker (see [[Roadmap]]). |
| Database | ArangoDB 3.12 Community | Official Docker/Podman images. |

## Cross-protocol type translation

| Logical type | Julia | JSON / GraphQL | Binary | Rule |
|---|---|---|---|---|
| 64-bit signed int | `Int64` | string or BigInt; `String` in GraphQL | `int64` | Values above 2^53−1 serialise as strings to avoid JavaScript truncation |
| 64-bit unsigned int | `UInt64` | string | `uint64` | Base-10 strings on browser-facing endpoints |
| Timestamp | `Dates.DateTime` | ISO 8601 UTC string | `int64` epoch | Millisecond precision, always UTC |
| Binary | `Vector{UInt8}` | Base64 string | `byte[]` / `Data` | RFC 4648 |
| Null vs omitted | `Union{Nothing,T}` vs `Missing` | `null` vs key absent | presence tag | `Nothing` is explicit null; `Missing` is omitted |
| Decimal / currency | `FixedPoint` or `String` | string | custom struct | `Float64` forbidden for money or exact scientific values |

## Protocol boundaries

- **gRPC** is deferred to Phase 8 (ADR-0006). Until then RPC means `MaridRPC` (JSON-RPC 2.0 / MCP over HTTP and SSE). Browser-facing gRPC must go through gRPC-Web or Connect.
- **GraphQL subscriptions** run over SSE first, WebSocket for bidirectional feeds.
- **Cap'n Proto and Bebop** are serialisation codecs inside `MaridCodec`, never RPC protocols.

## Governance sidecar

Production topology places the `http-capability-gateway` sidecar in front of the Marid HTTP service, with the backend on a private network and no host port. `MaridIR` emits the gateway's Verb Governance Spec (DSL v1 YAML) directly from the service descriptor, so routes and the perimeter policy cannot drift (ADR-0007, implemented locally for review, not deployed). The strict deny-by-default profile only holds with the paired gateway change, which landed upstream as gateway #112. See [[Deployment]] and [[Evidence]].

## Known stale statements in the sources

- `docs/marid-architecture.adoc` and `docs/marid-compatibility.adoc` call the Arango client `ArangoDB.jl`. The package is **`packages/MaridArango`** since 2026-09-22; the UUID is unchanged.
- The architecture spec says it was "approved at Gate 0". Gate 0 is not closed (the AffineScript toolchain is unproven); the design is the reconciled target, not an accepted release.
- The compatibility matrix lists verification evidence such as "wrk load benchmarks" and "Apollo Client compliance suite" as if they exist. `docs/audits/evidence-ledger.adoc` records which have actually run; most have not.

## Related pages

[[Charter]] · [[Packages]] · [[Decisions]] · [[Deployment]] · [[Glossary]]
