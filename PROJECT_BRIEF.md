<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

Provenance: transcribed 2026-09-18 from the owner's program brief ("Marid
project brief" through "9. Execution plan"). This file is the canonical
product/engineering contract for the Marid program. Do not edit its
requirements without owner approval; record estate-specific file mappings
(docs .md -> .adoc, RSR root shape) in AGENTS.md instead.

Amendment 2026-09-19 (owner-directed): the Marid framework charter
(docs/MARID-FRAMEWORK.adoc) is integrated. §1 gains the charter
principles, §2 is replaced by the charter's thirteen-package graph, §3–§9
are reconciled (IR-first, Bun runtime, AffineScript browser language,
gate→phase mapping). The charter governs build order; this brief governs
acceptance. Where they appear to disagree, docs/FRAMEWORK-ALIGNMENT.adoc
records the reconciliation.
-->

# Marid project brief

## 1. Product definition

Marid.jl is a Julia-first framework for web applications, APIs, and reactive scientific dashboards, with interoperable protocols and frontend independence.

Marid.jl is a clean-room reimplementation inspired by Genie.jl, with no shared code or API cloning. Its differentiators are: one service descriptor (IR), many protocol bindings, a pure local routing data plane with an optional consensus-backed control plane, and pluggable storage with ArangoDB as the flagship backend.

### Design commitments

- Application logic and original backend integrations are written in Julia.
- React, Vue, and other frontend frameworks are supported through standard APIs—not a proprietary rendering requirement.
- Protocol adapters remain independently usable.
- Transport, serialization, application services, and persistence are separate concerns.
- Distributed routing is an optional control-plane feature, not part of every request's execution.
- ArangoDB is the initial external database target. We are not building a database engine.
- Native protocol interoperability matters more than merely having packages with the right names.
- Control plane / data plane split: route lookup is a pure function over an immutable, locally cached snapshot. It never blocks, never touches the network.
- IR-first: every schema artifact is emitted from MaridIR. Nothing is hand-maintained in parallel.
- Seams before features: streaming-symmetric handlers, Transport, Codec, unified errors, and CallContext exist before any protocol adapter is written.
- Small packages, not a monolith: each concern ships independently and is independently useful.
- Standards over integrations: emit the standard artifacts; document the sidecar pattern for SSR; never chase framework-specific APIs.
- The HTML-first path (HTMX/Turbo/Datastar-style fragments) is first-class.
- Security comes from existing libraries. No hand-rolled crypto, sessions, or password hashing.
- Boring correctness over novel research in anything consensus-related.

### Licensing

- Original source, tests, examples, browser code, and authored tooling: MPL-2.0.
- Documentation prose and original documentation artwork: CC-BY-SA-4.0.
- Code samples in docs: MPL-2.0, stated explicitly.
- Third-party material retains its required licenses and notices.
- Explicit policies cover documentation snippets, docstrings, IDL files, generated code, and generator templates.
- Use the standard license texts, not a modified "MPL variant."
- Contributions: DCO sign-off, not CLA.
- Clean-room discipline: Genie.jl is MIT; study behavior, copy nothing.

Names, package registry availability, and relevant trademarks must be checked before public release.

## 2. Launch deliverables

Thirteen small packages in four waves, per the framework charter. We should not pretend any wave disappears from the workload.

### Launch set — Phase 1 (these make Marid possible)

| Package | Initial supported scope | Evidence required before calling it ready |
|---|---|---|
| MaridIR.jl | ServiceDescriptor, MethodDescriptor, TypeRef, Streaming, annotations. Pure data + validation; no dependencies | First emitter proves the IR; IR freezes; golden tests pass |
| MaridCodec.jl | Codec seam, content negotiation (Accept, q=, Vary), JSON via JSON3, ext-based MsgPack/CBOR | Negotiation matrix tested; JSON round-trips; extension seam exercised |
| MaridOpenAPI.jl | IR → OpenAPI 3.1 + JSON Schema 2020-12 emitters | Emitted specs validate with independent tooling |
| MaridRPC.jl | JSON-RPC 2.0 + MCP adapter over the IR, SSE transport hook | Independent JSON-RPC/MCP clients interoperate |
| MaridGraphQL.jl | IR → GraphQL SDL + introspection first; resolver runtime later | Standard GraphQL clients work against SDL/introspection; then queries, mutations, variables, partial errors, limits tested |

### Core — Phase 2

| Package | Initial supported scope | Evidence required before calling it ready |
|---|---|---|
| MaridTransport.jl | Transport seam; HTTP/1.1 impl (HTTP.jl), SSE, WebSocket upgrade, chunked/trailers | REST MVP serves from the IR; benchmark baseline recorded |
| MaridCore.jl | Router (trie, tuple key), middleware (f(call, next)), CallContext, server assembly | Router proven pure/non-blocking; middleware and lifecycle exercised by the reference app |

### Storage — Phase 3

| Package | Initial supported scope | Evidence required before calling it ready |
|---|---|---|
| ArangoDB.jl | HTTP-based Arango client: auth, pooling, cursors, AQL, transactions, retries, changefeeds | Tests against a real ArangoDB container; cursor cleanup, conflicts, failures, retry behavior tested |
| MaridStorage.jl | Storage seam + SQLite/DuckDB/in-memory impls; Arango impl as extension | SQLite/DuckDB/memory backends tested first; Arango extension tested against the container |

### Later — Phases 4–7

| Package | Initial supported scope | Evidence required before calling it ready |
|---|---|---|
| MaridControl.jl | Snapshot/atomic-swap, log abstraction, etcd/Consul backend, changefeed invalidation | Node serves with control plane down; swap is race-tested |
| MaridLive.jl | HTMX/Turbo/Datastar helpers over SSE/WS | Helpers exercised in real browsers against the reference app |
| MaridCRDT.jl | LWW-Register, OR-Set, G/PN-Counter, presence | Property tests + partition simulator pass |
| MaridRaft.jl | Own Raft (elections, log, compaction, membership) — only if etcd proves insufficient | Jepsen-style testing budget approved and executed |

### Further out — Phase 8

gRPC (HTTP/2 via libnghttp2 binding), CLI, generators, deployment docs. Gate: HTTP/2 conformance suite passes. If no production HTTP/2 server exists in Julia, accept gRPC-Web only.

### Important scope boundaries

For the initial release:

- Cap'n Proto message support (a MaridCodec extension) is not native Cap'n Proto RPC support. Cap'n Proto RPC (capabilities, promise pipelining) is a documented non-goal.
- Bebop v3 schema/runtime integration (a MaridCodec extension) enters via the IR, with an explicitly pinned schema/compiler/runtime.
- gRPC support must identify exactly which streaming modes work, once Phase 8 lands.
- GraphQL subscriptions require a separately identified transport implementation (SSE, then WebSocket).
- A Bebop or Cap'n Proto message sent over WebSocket must not be advertised as some other standard RPC protocol.
- A thin Julia wrapper around an audited external runtime is different from an entirely Julia implementation. Document that distinction.
- If adequate Julia tooling does not exist, the agent must report that before silently turning an adapter task into a runtime/compiler project.

### Non-goals (enforced in README and PR review)

Stipple-style reactive UI · Genie Builder-style visual editor · Genie API compatibility · Cap'n Proto RPC · SOAP/WSDL · HTTP/2 Push · SSR/Streaming SSR/RSC implemented in Julia · hand-rolled crypto · own Raft before everything else is stable · a Julia-native DBMS.

## 3. Repository and dependency structure

Start with one monorepo. The packages can still be independently versioned and registered.

```text
marid/
├── PROJECT_BRIEF.md
├── AGENTS.md
├── LICENSES/
├── REUSE.toml
├── THIRD_PARTY_NOTICES.md
├── docs/
│   ├── MARID-FRAMEWORK.adoc
│   ├── FRAMEWORK-ALIGNMENT.adoc
│   ├── architecture.md
│   ├── compatibility.md
│   ├── roadmap.md
│   ├── audits/
│   └── adr/
├── packages/
│   ├── MaridIR/
│   ├── MaridCodec/
│   ├── MaridOpenAPI/
│   ├── MaridRPC/
│   ├── MaridGraphQL/
│   ├── MaridTransport/
│   ├── MaridCore/
│   ├── ArangoDB/
│   ├── MaridStorage/
│   ├── MaridControl/
│   ├── MaridLive/
│   ├── MaridCRDT/
│   └── MaridRaft/
├── web/
│   ├── client/
│   ├── react/
│   ├── vue/
│   └── elements/
├── contracts/
├── fixtures/
├── examples/
│   └── relationship_explorer/
├── test/
│   └── interop/
└── scripts/
```

### Dependency rules

- MaridIR must not depend on anything. Every emitter depends on MaridIR, never the reverse.
- MaridCore must not unconditionally load every adapter.
- Adapter packages must work without a running Marid application.
- Adapters must not depend on one another.
- Marid-specific bindings should use optional integration modules or Julia package extensions where appropriate.
- Shared application-context definitions belong in the small core; standalone clients need not depend on them.
- Do not create a dozen utility packages before their interfaces have proved useful.

The architecture is:

```text
React / Vue / other frontends / RPC clients
                     │
          Protocol-specific interfaces
                     │
             Application services
     identity / policy / execution context
                     │
          Persistence and computation
                     │
                 ArangoDB
```

The request path in full (see the charter diagram):

```text
Request ──▶ Transport ──▶ MaridCore router ──▶ Middleware ──▶ Handler
        (reads immutable local snapshot)   (CallContext)   (Stream{I} → Stream{O})
                                                        │         ▲
                                                        ▼         │ atomic swap
                                              Codec pipeline  ControlPlane
                                                        │
                                                        ▼
                                                  Storage seam
```

Cap'n Proto and Bebop provide message/schema capabilities where explicitly supported, as MaridCodec extensions. They are not universal replacements for each protocol's native contract.

## 4. Establish these contracts before extensive implementation

These are the decisions that become expensive to retrofit.

| Contract | Required design |
|---|---|
| Execution context | Verified principal, tenant scope, deadline, cancellation, trace/request IDs |
| Application services | Ordinary Julia interfaces, not functions that require HTTP request objects |
| Authorization | Enforcement at service/resolver boundaries, not solely HTTP middleware |
| Streaming | Bounded buffering, slow-consumer behavior, cancellation, disconnect cleanup, ownership |
| Errors | Stable domain errors with protocol-specific mappings |
| Resource budgets | Message sizes, nesting, query cost, concurrency, execution duration |
| Lifecycle | Explicit application instances, startup, readiness, draining, shutdown |
| Contract evolution | Stable identifiers, native schemas, compatibility rules, pinned generators |
| Data ownership | Clear ownership/lifetime rules for borrowed buffers and decoded values |
| Retries | Explicit retryability and idempotency policy; no "exactly once" claims |
| Observability | Structured logs, operation-level metrics, trace propagation; no mandatory external telemetry |
| Persistence | Explicit transaction and cursor ownership, optimistic concurrency, pagination |

Additional requirements:

- No arbitrary Julia evaluation from network messages.
- No Julia object deserialization from untrusted clients as a shortcut for a wire protocol.
- Cancellation must not be represented as "the caller stopped waiting" while expensive work continues unnoticed.
- No global singleton holding user-specific authentication or tenant state.
- No automatic retries of writes unless their safety is established.

The charter's seams-before-features rule orders this work: streaming-symmetric handlers, the Transport seam, the Codec seam, unified errors, and CallContext exist before any protocol adapter is written.

### Preserve native schemas

Use:

- OpenAPI/JSON Schema for appropriate HTTP APIs.
- GraphQL SDL for GraphQL.
- `.proto` for gRPC.
- `.capnp` for Cap'n Proto.
- `.bop` for Bebop.

MaridIR is the contract registry's executable form: every native artifact above is emitted from the IR, and native schemas stay native at every boundary. The IR emits artifacts but is never a wire format. Marid maintains a contract registry containing identifiers, versions, fingerprints, and implementation bindings. It does not invent a replacement universal IDL.

Document translations for large integers, timestamps, binary data, null versus omitted values, and default values. Julia, JavaScript, GraphQL, and binary schemas do not have identical type semantics.

## 5. Browser compatibility

### Required foundation

- HTTP/JSON with OpenAPI 3.1 where applicable.
- GraphQL through its native interface.
- SSE for server-to-browser updates.
- A documented WebSocket application protocol where bidirectional communication is needed.
- Consistent HTTP errors using Problem Details where appropriate.
- Same-origin deployment as the simple default.
- Explicit cross-origin authentication and credential policies.

### Browser language and runtime

The browser language is AffineScript (JaffaScript face, `.affine` sources compiled to typed WebAssembly via `@hyperpolymath/affinescript`). The runtime and package manager is Bun. TypeScript is ejected for new application code; plain JavaScript appears only in narrow interop facades where the React/Vue ecosystem requires it.

### Browser packages

| Package | Purpose |
|---|---|
| `@metadatastician/marid-client` | Framework-independent client, cancellation, errors, live subscriptions, reconnect/resynchronization |
| `@metadatastician/marid-react` | Thin React integration and lifecycle cleanup |
| `@metadatastician/marid-vue` | Thin Vue integration and lifecycle cleanup |
| `@metadatastician/marid-elements` | Small portable Web Components demonstrator; not a new comprehensive widget library |

The AffineScript client should expose familiar interfaces:

- Promises.
- AbortSignal.
- Async iterables where useful.
- Snapshot/subscription interfaces for reactive state.

IR codegen targets AffineScript; generated clients reach the React/Vue/Svelte ecosystems through narrow JavaScript interop facades. Existing GraphQL and generated API clients should also work directly. Do not force every client through a universal Marid SDK.

### Compatibility requirements

- No window or document access merely from importing the SDK.
- Request-scoped credentials and caches for SSR use.
- Unmounting a component cleans up subscriptions.
- Reconnection detects missed updates and resynchronizes.
- Older browser bundles can remain compatible during rolling server deployments.
- SSR-safe SDK support does not mean Julia implements Next.js or Nuxt rendering.

For reusable controls, use Custom Elements, properties, DOM events, and explicit styling hooks. Provide framework wrappers only where they improve ergonomics.

SSR / RSC follow the sidecar pattern only, documented as recipes (Next.js/Nuxt → Marid API). Never reimplemented in Julia.

Browser-facing gRPC requires a separately selected gRPC-Web, Connect, or gateway approach. Native gRPC support alone is insufficient.

Static/SPA hosting: serve dist/, SPA fallback, MIME + precompressed variants, immutable caching. Documented Vite/Next/Nuxt dev-proxy recipes.

## 6. Routing, reactive state, and persistence boundaries

### Routing

Start with:

- Declarative route specifications.
- Validation.
- Versioned, immutable local snapshots.
- Local activation of complete revisions.
- A route-store interface with a local implementation.

Route lookup is a pure function over the snapshot: it never blocks and never touches the network. Consensus, config, and schema live only in the control plane (MaridControl.jl); nodes serve traffic with the control plane down, and Arango is never on the route-lookup path.

Later, Raft may distribute authoritative configuration — after everything else is stable, and only if the etcd backend proves insufficient.

Raft must not be used to replicate handler functions, ordinary requests, or live connections. Nodes must advertise which handlers and contract versions they actually have installed.

### Reactive state

Initially:

- Each session has one owning worker.
- Session state is isolated.
- Reconnection and worker failure have documented behavior.
- Durable state is stored separately.

CRDT support is a later, data-type-specific capability—not a promise that arbitrary Julia objects can be safely replicated.

### ArangoDB

Expose document, edge, and graph capabilities directly. Do not force them through a relational ORM abstraction.

The browser talks to application services, not directly to an unrestricted database endpoint.

Audit the exact ArangoDB release, edition, and deployment terms. Its internal Agency is not Marid's general-purpose consensus backend.

### Reserve interfaces, defer larger implementations

Establish extension boundaries for:

- Tables.jl and Arrow IPC.
- Identity-provider integration.
- Domain-event publication.
- Durable outbox implementations.
- Conditional writes and pagination.
- Background workers.
- Distributed route stores.

Do not include a new database, ORM, identity provider, Raft implementation, Arrow Flight service, or visual builder in the initial workload.

## 7. One reference application must exercise everything

Build a small relationship explorer backed by ArangoDB.

It should support:

- Creating and retrieving entities.
- Connecting entities with edges.
- Exploring a bounded neighborhood.
- Running a small Julia analysis with progress updates.

Expose the same application services through:

- HTTP/JSON.
- GraphQL.
- gRPC (once Phase 8 lands).

Provide Cap'n Proto and Bebop import/export fixtures or endpoints with explicitly documented semantics.

Build three frontends against those services:

- AffineScript (JaffaScript face).
- React.
- Vue.

Include one small shared Web Component, such as a progress indicator.

This application is the integration test—not a separate implementation of business logic for each protocol.

## 8. Definition of done

A package is ready only when it has:

- A documented public API.
- A supported-version and feature matrix.
- Unit tests.
- Real interoperability or database integration tests.
- Failure-path and resource-cleanup tests.
- A runnable example.
- Licensing and third-party notices.
- Reproducible installation and test instructions.
- CI for the declared Julia versions and platforms.
- An explicit list of unsupported features.

Mocks are useful for unit tests. They do not prove gRPC interoperability or ArangoDB compatibility.

Also measure:

- Julia cold startup and first useful response.
- Warm latency and allocations.
- Memory behavior under repeated connect/disconnect.
- Cancellation and shutdown behavior.

Never report skipped or unexecuted tests as passing.

Phase gates add their own evidence: golden tests (Phase 1), benchmark baseline (Phase 2), real-container integration tests (Phase 3), race-tested swap with control-plane-down serving (Phase 4), human-reviewed security checklist (Phase 5), property tests + partition simulator (Phase 6), approved Jepsen-style budget (Phase 7), HTTP/2 conformance suite (Phase 8).

## 9. Execution plan

### Gate 0 — Feasibility and licensing audit

Before production implementation:

- Inspect existing Julia packages and relevant native runtimes.
- Check maintenance, supported features, exact versions, licenses, and generated-code terms.
- Audit HTTP/2 and gRPC feasibility specifically.
- Audit Cap'n Proto and Bebop compiler/runtime feasibility.
- Audit GraphQL execution support—not just schema parsing.
- Audit AffineScript (JaffaScript face) readiness and the `@hyperpolymath/affinescript` release under Bun; approve the runtime choice or a fallback before Gate 4.
- Select an ArangoDB version for testing.
- Check proposed package names.

Produce an evidence-backed matrix:

| Integration | Existing implementation | Missing capabilities | License | Recommendation | Blocker |
|---|---|---|---|---|---|

Recommendations must distinguish:

- Reuse a Julia implementation.
- Build a Julia adapter over an audited external runtime.
- Contribute missing functionality upstream.
- Build new implementation work.
- Reduce or change scope.
- Stop for approval if a new runtime, substantial code generator, or non-Julia bridge is required.

### Gate 1 — Interoperability spikes

Prove the highest-risk assumptions using disposable, minimal examples:

- Standard client → proposed gRPC server.
- Independent Cap'n Proto implementation ↔ Julia.
- Independent Bebop implementation ↔ Julia.
- Standard GraphQL client → proposed executor.
- Julia client → actual ArangoDB instance.

Do not freeze the shared API until these results are understood.

### Gate 2 — Foundation

Create:

- Package skeletons and independent environments.
- License mapping.
- CI and test tooling.
- Shared context and lifecycle contracts.
- Architectural decision records.
- Browser-event contract.
- Toolchain pins: Julia versions for the CI matrix, Bun, and `@hyperpolymath/affinescript`.

Scaffolding alone does not constitute protocol support.

### Gate 3 — Independent packages

Implement the charter packages against their acceptance criteria (Phases 1–3 first; later phases follow the roadmap gates).

Parallel work is appropriate once the shared contracts and runtime choices have been approved.

### Gate 4 — Assembly and browser integrations

Implement:

- Thin Marid bindings.
- The framework-independent client.
- React/Vue wrappers.
- The reference application.
- Real-browser and cross-protocol tests.

### Gate 5 — Release review

Review:

- Support matrix.
- Security and failure behavior.
- Licensing.
- Documentation.
- Reproducibility.
- Package registration and release order.

Public registration, publishing, deployment, and use of paid services require explicit approval.

### Gate → phase mapping

The gates are acceptance checkpoints; the charter phases are build order. They cross like this:

| Gate | Covers phases | Notes |
|---|---|---|
| Gate 0 | Phase 0 + feasibility for all phases | Charter landed; audit matrix produced; runtime choices approved |
| Gate 1 | Phase 1–3 entry | Spikes de-risk gRPC, Cap'n Proto, Bebop, GraphQL execution, ArangoDB |
| Gate 2 | Phase 1–2 setup | Skeletons, contracts, pins (Julia, Bun, affinescript-cli) |
| Gate 3 | Phases 1–3, then 4–8 per roadmap | Packages implemented against §8 + phase gates |
| Gate 4 | Assembly + Phase 5 frontend | Client, wrappers, reference app, MaridLive |
| Gate 5 | Release review | Whole program, all phases |
