<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000002
parent: 6d617269-6400-7000-8000-000000000001
position: 10
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Charter

The Phase 0 charter fixes what Marid is, what it refuses to be, and the order in which it is built. The canonical text is `docs/MARID-FRAMEWORK.adoc` (transcribed 2026-09-19 from the owner's framework text) and the acceptance contract is `PROJECT_BRIEF.md` §1–§9. This page summarises both; where they differ, the brief governs acceptance and the charter governs build order.

Back to [[Home]].

## Mission

Marid.jl is an MPL-2.0 (code) / CC-BY-SA-4.0 (docs) Julia web framework, inspired by Genie.jl but a clean-room reimplementation with no shared code or API cloning. Its differentiators:

- one service descriptor (the IR) with many protocol bindings;
- a pure, local routing data plane with an optional consensus-backed control plane;
- pluggable storage with ArangoDB as the flagship backend.

## The twelve principles

1. **Control plane / data plane split.** Route lookup is a pure function over an immutable, locally cached snapshot. It never blocks and never touches the network. Consensus, config and schema live only in the control plane.
2. **IR-first.** Every schema artifact (OpenAPI, JSON Schema, GraphQL SDL, `.proto`, AsyncAPI, client stubs, docs) is emitted from MaridIR. Nothing is hand-maintained in parallel.
3. **Seams before features.** Streaming-symmetric handlers, Transport, Codec, unified errors and CallContext exist before any protocol adapter is written.
4. **No home-grown DBMS.** Storage is pluggable: SQLite/DuckDB/in-memory for dev and test, ArangoDB for production, with the Arango client its own package.
5. **Small packages, not a monolith.** Each concern ships independently and is independently useful.
6. **Standards over integrations.** Emit OpenAPI/JSON Schema/GraphQL/AsyncAPI/trace context; document the sidecar pattern for SSR; never chase framework-specific APIs.
7. **HTML-first path is first-class.** HTMX/Turbo/Datastar-style server-rendered fragments are a supported target.
8. **Security from existing libraries.** No hand-rolled crypto, sessions or password hashing.
9. **Explicit non-goals**, written down and enforced (below).
10. **Documentation is a deliverable**, licensed CC-BY-SA-4.0, built in CI.
11. **Contribution hygiene.** DCO sign-off (not CLA), SPDX headers everywhere, dependency review gate.
12. **Boring correctness over novel research** in anything consensus-related. Raft and CRDTs arrive late, small and tested, or not at all.

The per-principle Gate 0 status is tabulated in `docs/FRAMEWORK-ALIGNMENT.adoc`; see [[Roadmap]] for where each gate stands today.

## Non-goals (enforced in README and PR review)

Stipple-style reactive UI · Genie Builder-style visual editor · Genie API compatibility · Cap'n Proto RPC (capabilities, promise pipelining) · SOAP/WSDL · HTTP/2 Push · SSR/Streaming SSR/RSC implemented in Julia · hand-rolled crypto · own Raft before everything else is stable · a Julia-native DBMS.

## Protocol matrix

| Protocol | Timing | Blocker | Notes |
|---|---|---|---|
| REST/JSON (IR + OpenAPI) | Phase 1 launch set | none | Flagship, first-class |
| JSON-RPC / MCP | Phase 1 launch set | none | High-value ecosystem adapter |
| GraphQL (SDL, then runtime) | Phase 1 launch set | none | Subscriptions via SSE, then WS |
| SSE + WebSocket | Core | transport seam | Enables Live and the HTML path |
| gRPC | after HTTP/2 transport lands | no production HTTP/2 server in Julia | Bind libnghttp2 or accept gRPC-Web only; see ADR-0006 in [[Decisions]] |
| Cap'n Proto | serialization only | zero-copy needs ByteBuf design | RPC is a documented non-goal |
| Bebop | low-medium | no Julia tooling; wire format simple | Schema enters via IR |
| MsgPack/CBOR | free with the Codec seam | none | |

## Frontend story

- **API consumers** get OpenAPI 3.1 + JSON Schema and GraphQL SDL, so codegen is free from the IR.
- **Static/SPA hosting**: serve `dist/`, SPA fallback, MIME and precompressed variants, immutable caching.
- **No-JS path**: MaridLive (HTMX headers, Turbo Streams, Datastar attributes over SSE/WS).
- **SSR / RSC**: sidecar pattern only, documented as recipes. Never reimplemented in Julia.
- **Browser language**: AffineScript, not TypeScript. See the adaptations below and [[Web-SDKs]].

## Storage story

Storage interface: get, put, delete, query, transaction, cursor, watch, Capabilities. Backends: SQLite (dev/test), DuckDB (analytical/dev), in-memory (tests), ArangoDB (production flagship). No Julia-native DBMS exists or will be attempted.

## Licensing

- Code: MPL-2.0, file-level copyleft, SPDX header on every source file.
- Docs: CC-BY-SA-4.0 under `docs/`, with its own LICENSE and SPDX headers on content. Code samples in docs are MPL-2.0, stated explicitly.
- Contributions: DCO sign-off, not CLA. CI fails unsigned commits.
- Clean-room discipline: Genie.jl is MIT; study behaviour, copy nothing. No "Genie" in names, logos or descriptions beyond factual attribution.

See [[Contributing]] for the exact header text and the sign-off workflow.

## Marid-local adaptations

Three places where the estate overrules or sharpens the charter text. Each is a noted decision, not silent drift.

1. **TypeScript ejection.** Estate ruling 2026-08-25 (`LANGUAGE-POLICY.adoc` §1.2): TypeScript is not the language for new application code; AffineScript is. IR codegen targets AffineScript (`.affine` sources compiled to typed WebAssembly via `@hyperpolymath/affinescript` under Bun); generated clients reach React/Vue/Svelte through narrow plain-JavaScript facades.
2. **IR versus registry.** The brief forbids "a replacement universal IDL"; the charter mandates IR-first. Reconciled: MaridIR is the contract registry's executable form, native schemas stay native at every boundary, and the IR is never a wire format. `contracts/` records identifiers, versions, fingerprints and bindings.
3. **Gates versus phases.** The brief's six Gates 0–5 are the program's acceptance gates; the charter's Phases 0–8 are the build order. The mapping is in `PROJECT_BRIEF.md` §9 and verified in `docs/FRAMEWORK-ALIGNMENT.adoc`. See [[Roadmap]].

## Known stale statements in the sources

- `docs/MARID-FRAMEWORK.adoc` and `PROJECT_BRIEF.md` name the Arango client package `ArangoDB.jl`. It was renamed to **MaridArango** on 2026-09-22 (D57, marid PR #41); the UUID `719c9fe8-…` was kept. Read `ArangoDB.jl` in the charter as `packages/MaridArango`.
- Principle 10 says documentation is "built in CI with Documenter.jl". No Documenter build exists yet; `docs/FRAMEWORK-ALIGNMENT.adoc` lists it as a gap.
- The charter's frontend story still names `openapi-typescript` and Apollo/urql/Relay codegen as examples. Adaptation 1 above supersedes them.

## Related pages

[[Architecture]] · [[Packages]] · [[Roadmap]] · [[Decisions]] · [[Glossary]]
