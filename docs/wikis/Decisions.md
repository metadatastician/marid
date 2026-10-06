<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000008
parent: 6d617269-6400-7000-8000-000000000001
position: 70
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Decisions

The architectural decision records (ADRs) for the Marid program live in `docs/adr/`, one decision per file, named `NNNN-short-title.adoc` and numbered in the order decided. Each record states the context, the decision, the alternatives considered, and the consequences, including what becomes expensive to retrofit if the decision is wrong (`PROJECT_BRIEF.md` §4). Records are immutable once accepted; a superseded record stays in place with a pointer to its successor.

`docs/decisions/` is a different thing: it holds the RSR template's own decisions (0001 to 0003, the scaffolding's history), not Marid program decisions.

This page summarises the seven records that exist as of 2026-10-06. The files are authoritative; read them before relying on a summary here. For how the decisions fit together see [[Architecture]]; for what has actually been proven about each see [[Evidence]]; for the gated build order they serve see [[Charter]] and [[Roadmap]].

| ADR | Title | Status | Date |
|---|---|---|---|
| 0001 | IR-First Architecture and Contract Generation | accepted | 2026-09-19 |
| 0002 | Control Plane and Data Plane Split | accepted | 2026-09-19 |
| 0003 | Protocol Adapter Seams and Symmetric Streaming Handlers | accepted | 2026-09-19 |
| 0004 | Native Julia HTTP Client for ArangoDB | accepted | 2026-09-19 |
| 0005 | AffineScript Browser Client under Bun Runtime | accepted | 2026-09-19 |
| 0006 | Defer Native gRPC to Phase 8 and Launch with MaridRPC | accepted | 2026-09-19 |
| 0007 | Emit native HTTP Verb Governance Specs from MaridIR | implemented locally for review, 2026-09-19. No deployment approved. Updated 2026-09-20. | 2026-09-19 |

## ADR-0001: IR-First Architecture and Contract Generation

File: `docs/adr/0001-ir-first-architecture.adoc`. Status: accepted (2026-09-19).

**Context.** A multi-protocol framework that supports REST/JSON, GraphQL, gRPC and binary formats (Cap'n Proto, Bebop) easily degenerates into schema drift. If developers maintain OpenAPI specs, GraphQL SDL and Protobuf files separately in parallel, the contracts diverge, producing runtime failures and fragile client SDKs.

**Decision.** Marid adopts an IR-first architecture in `packages/MaridIR/`. `MaridIR` is a pure data representation of services, methods, types and streaming semantics in Julia. All external contract artifacts (OpenAPI 3.1 JSON, GraphQL SDL, Protobuf `.proto`, Bebop `.bop`, JSON Schema 2020-12) are emitted programmatically from this single source of truth. The IR is never transmitted over the wire and is not a runtime wire format.

**Alternatives rejected.** GraphQL SDL as the universal IDL (lacks first-class semantics for binary framing, streaming flow control and gRPC status trailers); Protobuf as the universal IDL (forces a heavyweight `protoc` dependency and impedes idiomatic Julia type definitions); hand-maintained per-protocol schemas (guarantees drift).

**Consequences.** Zero contract drift across protocols: schema changes in `MaridIR` propagate to all emitted contracts and client SDKs. The trade-off is that `MaridIR` must be expressive enough to capture the union of protocol capabilities without becoming a bloated universal IDL. Expensive to retrofit: adding an IR after adapters are built on hand-written schemas would mean rewriting every endpoint definition.

## ADR-0002: Control Plane and Data Plane Split

File: `docs/adr/0002-data-control-plane-split.adoc`. Status: accepted (2026-09-19).

**Context.** Distributed web frameworks often entangle route matching with dynamic service discovery, distributed locks or database queries. When the consensus layer fails or the network partitions, request routing fails or suffers latency spikes.

**Decision.** Marid strictly separates the two planes. The data plane (`MaridCore`) resolves routes as a deterministic pure function over an immutable, locally cached radix/trie snapshot (`RouteTable`); it never takes locks, never blocks and never touches the network. The control plane (`MaridControl`) owns configuration distribution, consensus and route table updates; a new configuration is compiled into a new immutable `RouteTable` and swapped in with an atomic pointer swap. Nodes keep serving at wire speed even if the control plane (etcd, Consul or Raft) is completely unreachable.

**Alternatives rejected.** Synchronous distributed route lookup on each match (unacceptable latency, single point of failure); mutable in-place route trees under read-write locks such as `ReentrantLock` (lock contention and registration races).

**Consequences.** Predictable sub-microsecond route resolution, zero lock contention, total resilience against control-plane outages. The trade-off is that route propagation across a cluster is eventually consistent rather than instantaneous. Expensive to retrofit: handlers or routing logic that assume synchronous shared state during route evaluation would force a re-architecture of the whole request lifecycle.

## ADR-0003: Protocol Adapter Seams and Symmetric Streaming Handlers

File: `docs/adr/0003-protocol-adapter-seams.adoc`. Status: accepted (2026-09-19).

**Context.** Frameworks typically couple handlers to HTTP request and response objects (`req::HTTP.Request, res::HTTP.Response`). Adding WebSockets, gRPC or message queues then means rewriting handlers or wrapping them in awkward mock HTTP objects, which breaks streaming and flow control.

**Decision.** Application services are protocol-agnostic, streaming-symmetric Julia functions of the form `handler(ctx::CallContext, input::Stream{I})::Stream{O}`. Three explicit seams isolate protocol mechanics from domain logic: `MaridTransport` converts wire frames (HTTP/1.1, WebSocket, SSE) into raw byte streams and owns the request lifecycle; `MaridCodec` negotiates content types (`Accept`, `Content-Type`) and converts byte streams to and from typed `Stream{I}` / `Stream{O}`; `CallContext` propagates the verified principal, tenant, deadlines, cancellation signals and distributed trace context. Application services have zero dependency on HTTP or transport types.

**Alternatives rejected.** The HTTP-centric `handle(req) -> resp` signature (incompatible with gRPC streaming, WebSocket duplex traffic and background workers); macro-generated wrapper boilerplate (obscures data flow, hinders static analysis and unit testing).

**Consequences.** Handlers are reusable across HTTP/JSON, GraphQL, JSON-RPC and gRPC without duplicated business logic. The trade-off is that developers must learn the streaming-symmetric interface even for unary endpoints (unary is a one-element stream). Expensive to retrofit: coupling handlers to raw HTTP objects early makes multi-protocol support prohibitively costly later.

## ADR-0004: Native Julia HTTP Client for ArangoDB

File: `docs/adr/0004-arangodb-native-http-client.adoc`. Status: accepted (2026-09-19).

**Context.** ArangoDB is the flagship multi-model persistence backend (documents, edges, graphs). At the time of the decision there was no active, supported ArangoDB client in the Julia General Registry. The framework needs a database layer that does not force graph and document capabilities through a relational ORM abstraction.

**Decision.** Build the ArangoDB client as an independent, standalone Julia package that talks to ArangoDB's official HTTP/REST API (port 8529) through `HTTP.jl` connection pools and `JSON3.jl` serialization. Four properties: standalone scope (usable without `MaridCore`); direct capabilities (document CRUD, edge collections, bound AQL via `POST /_api/cursor`, cursor pagination and cleanup, stream transactions); integration with `MaridStorage` through a Julia package extension so the storage abstraction stays separate from the concrete client; and no ORM (documents and graph results are typed structs or zero-allocation JSON views).

The record names the package `ArangoDB.jl` at `packages/ArangoDB/`. The package has since been renamed `MaridArango` and lives at `packages/MaridArango/` (UUID unchanged); see the stale-statement section at the end of this page and [[Packages]].

**Alternatives rejected.** Wrapping an external C/C++ driver via FFI (build-toolchain and memory-management seams, while ArangoDB's native interface is JSON over HTTP, which Julia handles natively); a relational ORM abstraction (destroys ArangoDB's value proposition of graph traversals and schemaless document trees).

**Consequences.** A lightweight pure-Julia implementation with no external C library dependencies and full fidelity for graph traversals and AQL. The trade-off is that HTTP wire parsing, cursor batching and conflict handling must be implemented and maintained in Julia. Expensive to retrofit: wrapping an ORM around documents would make graph algorithms (`Cladistics.jl`) unnatural and inefficient.

Note from [[Evidence]]: as of the evidence ledger, persistence against a real ArangoDB is still unproven; the recon found the client's public operations using an in-memory mock. The decision is accepted; its implementation is not release-accepted.

## ADR-0005: AffineScript Browser Client under Bun Runtime

File: `docs/adr/0005-affinescript-browser-client.adoc`. Status: accepted (2026-09-19).

**Context.** Frontend applications need client SDKs for API calls, live event subscriptions (SSE/WS) and reactive state synchronisation. Estate policy (ruled 2026-08-25) places TypeScript in the forbidden category for new application code and selects Bun as the unified runtime, ejecting Node, npm, yarn, pnpm and Deno.

**Decision.** Marid's browser packages under `web/` are written in AffineScript (the JaffaScript surface face, compiling `.affine` sources to typed WebAssembly via `@hyperpolymath/affinescript`) and managed with Bun. Three layers: a core SDK exposing standard web interfaces (`Promise`, `AbortSignal`, `AsyncIterable`, reactive subscriptions); thin React and Vue lifecycle wrappers that clean up subscriptions on unmount and detect missed updates on reconnection, with plain JavaScript facades where idiomatic ergonomics require them; and framework-independent Web Components for progress and connection-status indicators. The record names these `@marid/client`, `@marid/react`, `@marid/vue` and `@marid/elements`; the current package names are listed on [[Web-SDKs]].

**Alternatives rejected.** A TypeScript client SDK (violates estate policy); a pure WebAssembly/Rust client (heavy payload, poor integration with ordinary React and Vue applications).

**Consequences.** Memory and affine resource safety at the browser edge, plus Bun's package management and execution speed. The trade-off is reliance on the `@hyperpolymath/affinescript` compiler, whose upstream stability was to be verified during Gate 2. Expensive to retrofit: committing to TypeScript would create estate policy violations requiring every client-facing package to be rewritten.

Note from [[Evidence]]: the ledger records that AffineScript compilation is still a feasibility blocker, that the shipped `web/` entrypoints are JavaScript, and that the React/Vue tests use shims rather than real browsers.

## ADR-0006: Defer Native gRPC to Phase 8 and Launch with MaridRPC

File: `docs/adr/0006-defer-native-grpc-to-phase-8.adoc`. Status: accepted (2026-09-19).

**Context.** The initial brief proposed `MaridGRPC.jl` as a Phase 1 launch deliverable. The Gate 0 feasibility audit (`docs/audits/feasibility.adoc`) found that the Julia ecosystem lacks a production-grade multiplexing HTTP/2 server: `HTTP.jl` is an HTTP/1.1 engine, and experimental pure-Julia HTTP/2 libraries (`PureHTTP2.jl`) lack flow-control windowing and battle-testing. Building a pure-Julia HTTP/2 and gRPC engine in Phase 1 would turn Marid into an unbudgeted low-level networking project.

**Decision.** Reconcile the gRPC roadmap with `docs/MARID-FRAMEWORK.adoc`. Launch RPC in Phase 1 with `MaridRPC.jl`, supporting JSON-RPC 2.0 and the Model Context Protocol (MCP) over HTTP/1.1 and Server-Sent Events. Defer native gRPC to Phase 8, where it will use `JuliaIO/gRPCServer.jl` with `Nghttp2Wrapper.jl` (an FFI binding to C `libnghttp2`) or a gRPC-Web gateway for browsers. gRPC unary and server streaming are prioritised; bidirectional streaming stays gated on robust HTTP/2 stream multiplexing.

**Alternatives rejected.** Implementing pure-Julia HTTP/2 in Phase 1 (massive overhead, high stability risk); dropping RPC entirely in favour of REST and GraphQL (AI-agent integration via MCP and microservice communication need structured RPC).

**Consequences.** De-risked Phase 1 deliverables and immediate high-value RPC (JSON-RPC plus MCP) without reinventing HTTP/2. The trade-off is that native `.proto` gRPC endpoints are not in the Phase 1 MVP. Expensive to retrofit: an unstable custom HTTP/2 stack built early would mean fragile connections, memory leaks and prolonged debugging.

Note from [[Evidence]]: the recon found `MaridRPC` to be in-process dispatch with no MCP lifecycle or transport implementation yet; the ADR's sequencing stands, but the launch deliverable is not release-accepted.

## ADR-0007: Emit native HTTP Verb Governance Specs from MaridIR

File: `docs/adr/0007-native-capability-spec.adoc`. Status: "implemented locally for review, 2026-09-19. No deployment approved." The record carries an update dated 2026-09-20.

**Context.** The owner requested `emit_capability_spec` in `MaridIR` and the CLI, plus a front-facing `http-capability-gateway` Compose sidecar. The charter requires IR-first artifacts and independent packages, and `MaridIR` must stay dependency-free. The inspected gateway revision (`19b343c1e9b7c61668c60887369783d12a486f41`) consumes native DSL v1 YAML rather than the historical v0 document; its validator rejects empty global verb lists, its compiler falls back to public global verbs for unknown paths and missing route verbs, and regex precedence was unordered.

**Decision.** Emit deterministic YAML text with a small scalar encoder (single quotes, doubled apostrophes, rejected control and line characters) rather than adding a YAML library. Do not change the IR types, add a protocol dependency, hand-maintain parallel policy or hide gateway changes inside Marid. Keep the legacy profile as default with mandatory non-empty explicit `global_verbs`; add opt-in `gateway_profile=:strict, global_verbs=String[]` and the CLI flag `--deny-by-default`. Strict mode requires the paired gateway correction; an unpatched validator rejects it rather than silently broadening access. The gateway correction allows empty globals, makes a matched path own its whole verb allowlist, gives exact paths precedence, and denies multiple matching regex patterns. Verbs at identical paths are combined; exposure and capability metadata must be consistent; literal paths are escaped, colon parameters and terminal wildcards translated, patterns anchored, and overlaps or gateway-management collisions rejected. Annotation names are `gateway.exposure` and `gateway.capability`, with service defaults and method overrides; capability strings are labels, not tokens, and authorization stays at the application and authenticated ingress boundaries. CLI input is a trusted Julia file returning a descriptor; paths are passed through `ARGS`, and descriptor stdout is isolated from emitted YAML. The pre-existing proto/openapi/graphql CLI stubs are outside this bounded change. Compose consumes reviewed images with no fabricated registry tags and the backend has no published port.

**Evidence and consequences.** `packages/MaridIR/test/capability.jl`, `test/interop/capability_cli.sh` and `test/interop/capability_gateway.exs` test emission and the real native policy pipeline in both profiles; `test/interop/run_http_gateway.sh` proves the full network path and backend outage. A SHA-pinned gateway CI job exercises the correction. The broader gateway suite had 15 reproducible baseline failures, and dependency advisories remain production blockers. The sidecar is limited to bounded unary HTTP pending proxy, streaming and security validation; overlapping Marid routes may need redesign. No core routing semantics or brief requirements change. The full contract and release gate are in `docs/deployment/docker-compose.adoc`; see [[Deployment]] and [[Evidence]].

**Update (2026-09-20).** The decision originally authorised "a separately delivered gateway patch, not an upstream push". That premise changed: the gateway repository merged the correction as `hyperpolymath/http-capability-gateway#112`, commit `c67c743c6c9f54c0482c1dd8d8dc151ff919551d`. Strict mode no longer depends on an unmerged local artifact, so `test/interop/gateway-strict.patch` was deleted (it had also become unapplicable: `corrupt patch at ...:270`, four hunks whose line counts did not match their bodies) and `capability-spec.yml` pins the merged commit and greps `policy_validator.ex` for the empty-globals clause instead of patching. Everything else stands: legacy profile default, `:strict` opt-in, and an image built before the correction still rejects `global_verbs: []`. No Marid-side behaviour changed.

## Program-level rulings

Owner-level decisions about the Marid program (sequencing, scope, what is and is not approved) are not recorded as ADRs in this repository. They live in a D-numbered decision ledger outside the repo: `hyperpolymath/standards` issue #787 carries the D-numbered rulings, and marid issues #11 to #26 carry the D56+ rows, one row per issue. Consult those before treating anything on this page as the last word on program direction. Their contents are not reproduced here. See [[Governance]].

## Known stale statements in the sources

Recorded rather than silently corrected, because the ADR files are immutable once accepted:

- `docs/adr/README.adoc` ends with "Status: Gate 0 not yet started; no Marid ADRs exist yet." This is stale: seven ADRs exist in the same directory, six accepted on 2026-09-19 and one implemented locally for review on the same date. The README's conventions section is still correct.
- `docs/adr/0004-arangodb-native-http-client.adoc` names the package `ArangoDB.jl` at `packages/ArangoDB/`. The directory is now `packages/MaridArango/` and the package is named `MaridArango` (`Project.toml` name `MaridArango`, UUID `719c9fe8-89eb-588d-a237-0159f38ee2e4`, unchanged by the rename). The feasibility audit's "Available (unregistered)" check for the name `ArangoDB` predates the rename.
- `docs/adr/0005-affinescript-browser-client.adoc` cites estate policy as `ANCHOR.a2ml` (twice). Zero `.a2ml` files exist in the repository; that format was replaced by `.deed`. The ruling of 2026-08-25 that the ADR relies on is unaffected; only the file citation is stale.
- `docs/adr/0007-native-capability-spec.adoc` and its update refer to the gateway as `hyperpolymath/http-capability-gateway`; that reference is to a different repository and is not a Marid URL. Any `github.com/hyperpolymath/marid` URL encountered elsewhere in the docs tree is stale: the repository is `github.com/metadatastician/marid`.
- The ADRs pre-date the thirteen-package inventory and name `@marid/client`, `@marid/react`, `@marid/vue` and `@marid/elements` for the browser packages; see [[Web-SDKs]] for the current names.
