<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000015
parent: 6d617269-6400-7000-8000-000000000001
position: 140
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Glossary

Terms as Marid and the estate use them. Where a term is also a package, the package page is [[Packages]].

Back to [[Home]].

## Marid concepts

- **IR (Intermediate Representation).** The single in-memory description of a service: `ServiceDescriptor` → `MethodDescriptor` → `TypeRef`, with streaming modes and annotations. Every schema artifact is emitted from it; it is never a wire format. Package: MaridIR.
- **ServiceDescriptor / MethodDescriptor / TypeRef.** The three IR node kinds: a named service, one callable on it (route, verb, input/output types, streaming mode), and a reference to a logical type with its cross-protocol translation rule.
- **CallContext.** Immutable per-request record carrying `principal`, `tenant_scope`, `deadline`, `cancellation` and `trace_id`. The only way request-scoped state reaches a handler.
- **Handler.** `(ctx::CallContext, input::Stream{I}) -> Stream{O}`. Transport-agnostic; unary calls are one-element streams.
- **Seam.** An abstract interface placed before any implementation exists: Transport, Codec, Storage, Control. "Seams before features" is charter principle 3.
- **Data plane / control plane.** The data plane serves requests from an immutable local RouteTable snapshot and never touches the network for a lookup. The control plane (consensus, config, schema) publishes new snapshots by atomic swap and may be down without stopping traffic.
- **RouteTable snapshot.** The immutable trie the router reads. Replaced whole, never mutated.
- **Codec.** Encoder/decoder selected by content negotiation (Accept, q-values, Vary). JSON via JSON3 first; MsgPack, CBOR, Cap'n Proto and Bebop as serialisation only.
- **Changefeed.** A stream of database change events (ArangoDB) used to invalidate control-plane caches. Never on the request path.
- **AQL.** ArangoDB Query Language.
- **`_rev`.** ArangoDB's per-document revision token; Marid's optimistic-concurrency check.
- **Problem Details.** RFC 9457 JSON error body. Every `MaridError` maps to one over HTTP.
- **MaridError.** The root domain exception type; adapters translate it to protocol-native errors.
- **Verb Governance Spec / DSL v1.** The YAML policy consumed by the `http-capability-gateway` sidecar. MaridIR emits it from the service descriptor so routes and perimeter policy cannot drift.
- **Sidecar.** The Elixir `http-capability-gateway` placed in front of the Marid HTTP service in the production topology. Also the pattern for SSR/RSC, which Marid never implements in Julia.
- **Relationship explorer.** The one reference application (`examples/relationship_explorer`, package `RelationshipExplorer`) that must exercise persistence, every adapter and a real browser before Gate 4 closes.
- **Launch set.** The Phase 1 packages: MaridIR, MaridCodec, MaridOpenAPI, MaridRPC, MaridGraphQL.
- **Gate vs Phase.** Gate (0–5): an acceptance boundary with exit criteria, from the brief. Phase (0–8): build order, from the charter. See [[Roadmap]].
- **Clean-room.** Behaviour studied, code never read or copied. Marid's relationship to Genie.jl.

## Estate terms

- **Hub / satellite.** The hub is the `marid` monorepo. The satellites were the 18 standalone repositories created by the 2026-09-19 fan-out; they are retired. See [[Ecosystem]].
- **D-row (D53, D117, …).** A numbered owner decision in the estate ruling ledger (`hyperpolymath/standards#787` and the local ledger). Never renumbered; struck when answered. See [[Decisions]].
- **ADR.** Architecture Decision Record, `docs/adr/ADR-NNNN-*.adoc`.
- **RSR.** The estate's repository standard (`hyperpolymath/standards`), from which `rsr-template-repo` and hence this repository's CI skeleton derive.
- **descriptile / deed.** The machine-readable repository descriptors under `.machine_readable/descriptiles/` (`STATE`, `META`, `ECOSYSTEM`, …) and the `.deed` s-expression files that carry them. The former `.a2ml` format no longer exists anywhere in the repository.
- **`actions.lock`.** `.github/workflows/actions.lock`, the per-workflow set of SHA-pinned action references verified by the governance gate. Regenerate only with `gh actions-lock --no-narrow`; a hand edit or a stale lock startup-kills the workflows it names. See [[CI-and-Operations]].
- **Startup death / `startup_failure`.** A workflow that fails before any job starts. Its required checks read as absent, not failing, so a PR can look clean while a gate has silently stopped running.
- **DCO.** Developer Certificate of Origin: `Signed-off-by:` on every commit. Marid uses DCO, not a CLA.
- **SPDX.** License identifiers in file headers (`MPL-2.0` for code, `CC-BY-SA-4.0` for docs). Enforced by a validator.
- **AffineScript / JaffaScript.** The estate's browser language, compiled from `.affine` sources to typed WebAssembly via `@hyperpolymath/affinescript`. JaffaScript is its JavaScript-shaped surface. TypeScript is banned estate-wide.
- **Bun.** The only sanctioned JavaScript runtime and package manager. Node, npm and Deno are not used.
- **BerryWiki.** The estate's notebook format for human-facing documentation (`metadatastician/berrywiki`): Markdown pages with a `<!-- berrywiki … -->` metadata block, a generated `_Sidebar.md`, and `berrywiki check` as the validator. This notebook is one.
- **Bounded observation.** The estate rule (AGENTS.md §5) that a count or an absence is only as good as the instrument's reach; state the scope with the claim.
- **Vacuous gate.** A check that reads as protection but can never fail (an empty required-checks list, a workflow whose only secret does not exist). Several marid issues are of this kind.

## Related pages

[[Charter]] · [[Architecture]] · [[Packages]] · [[CI-and-Operations]]
