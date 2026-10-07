<!-- berrywiki
id: 01a115aa-ca27-8c65-b2fc-5e5ae9d866d1
parent: 01a115aa-ca16-8134-837f-254d19a045bf
position: 50
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Roadmap

What is planned, in what order, and where each item stands. Three documents define it: the charter's build phases (`docs/MARID-FRAMEWORK.adoc`), the brief's acceptance gates (`docs/marid-roadmap.adoc`, `PROJECT_BRIEF.md` §9) and the recovery plan that re-sequenced everything after the 2026-09-19 reconnaissance (`docs/plans/charter-recovery-and-next-steps.adoc`). The live owner rulings that cut across them are on [[Decisions]]; what has actually been proven is on [[Evidence]].

Back to [[Home]].

## Gates versus phases

The brief's **Gates 0–5** are acceptance gates: each has exit criteria and nothing after it is claimed until it closes. The charter's **Phases 0–8** are build order. The mapping:

| Gate | Exit criterion (short) | Charter phases | Status |
|---|---|---|---|
| 0 Feasibility and licensing | Clean-room statement; toolchain proven; Arango edition/licence audit; AffineScript compiles to Wasm | 0 | **Open.** AffineScript toolchain unproven; Arango exact-version audit pending |
| 1 Spikes | IR → OpenAPI, GraphQL SDL, JSON-RPC each proven on a real socket | 1 | Partial: HTTP/JSON unary slice proven; GraphQL and RPC in-memory only |
| 2 Foundation | Transport, Core, Codec, CallContext, errors wired; contracts recorded | 2 | Partial: 38 real HTTP assertions pass; cancellation, readiness, draining open |
| 3 Independent packages | Each of the 13 passes its own suite without the hub | 3 | Unit suites pass; independent interop not proven |
| 4 Assembly and browser | Relationship explorer bound to IR, persistence, real browser | 4–7 | Not started as acceptance; explorer is in-memory |
| 5 Release review | Brief §8 definition of done | 8 | **Not accepted.** The Gate 5 "100% MVP" claim of 2026-09-19 is superseded |

The 2026-09-19 recon found both failure modes at once: the indexed "nothing exists" summary was stale, and the "all gates complete, production-ready" claim was unsupported. Both are retired in favour of the evidence ledger.

## Critical path (recovery plan, 2026-09-19)

```
Evidence / CI repair
  → IR + Codec correctness → real HTTP Core
  → native gateway fixes → governed unary end-to-end
  → real storage → relationship explorer on persistence
  → adapter interop → real browser acceptance
  → release review
  → optional Control / Live / CRDT → conditional Raft
  → gated HTTP/2 (gRPC)
```

Deferred until the above are proven: Julia General registration (see the D117 note below), polyrepo extraction, and an own Raft.

## Work packages

**A. Accept the bounded capability change.** `emit_capability_spec`, DSL v1 YAML, the `capability_cli`, the Compose topology. Implemented and evaluated against the real gateway policy pipeline. Remaining acceptance: a hosted CI run and the lockfile reconcile.

**B. Recover evidence, CI and feasibility.** Requirements-to-evidence ledger (done: `docs/audits/evidence-ledger.adoc`); supersede the stale Gate 5 claim (done); fix the required-file mappings (done, via root symlinks); regenerate `actions.lock` (recurring, see [[CI-and-Operations]]); pin Julia 1.10.10 and Bun 1.4.2 (done); prove AffineScript → Wasm executes (**open**); re-audit Arango licensing at the exact version (**open**).

**C. IR, Codec, Core on a real path.** C1: IR schema artifacts (OpenAPI path merging, component emission). C2: JSON3 wire encoding, q-values, HTTP.jl adapter, root-routing fix, cancellation, startup/readiness/draining, W3C trace propagation. Checkpoint 2 landed the unary HTTP/JSON slice.

**D. Strict gateway and real sidecar acceptance.** Deny-by-default DSL, deterministic precedence, atomic policy publish, pinned non-root image, SSRF and hop-by-hop hardening, Compose stack with no backend host port. The paired gateway change merged upstream as `http-capability-gateway#112`; the full gateway suite still carried 15 failures at last record.

**E. Storage and the reference vertical slice.** Real Arango client (not the dictionary mock), SQLite/DuckDB adapters, tests against a pinned Arango container, relationship explorer bound to the IR.

Status line from the plan, unchanged until the ledger says otherwise: *38 real HTTP assertions pass; strict policy plus gateway-to-Julia socket tests pass with the paired gateway patch. Full gateway suite remains red (15 failures); dependency advisories and container/hosted CI gates remain. No production or later-phase acceptance follows.*

## Charter phase table (build order)

| Phase | Name | Content | Hard dependency |
|---|---|---|---|
| 0 | Charter | this document set, licences, non-goals, DCO, CI skeleton | none |
| 1 | IR + launch set | MaridIR, MaridOpenAPI, MaridGraphQL (SDL), MaridRPC | none |
| 2 | Core and seams | MaridTransport, MaridCodec, MaridCore | Phase 1 |
| 3 | Storage | MaridStorage, MaridArango | Phase 2 |
| 4 | Control plane | MaridControl | Phase 2; etcd available |
| 5 | HTML-first | MaridLive | Phase 2 |
| 6 | Collaboration | MaridCRDT | Phase 4 |
| 7 | Own consensus | MaridRaft (optional) | Phase 4 stable; a proven need |
| 8 | HTTP/2 and gRPC | libnghttp2 binding or gRPC-Web decision | Phase 2 stable |

## Live dates and rulings that move the roadmap

- **D117. Julia General registration due 2026-10-14.** Tier-1 submission (the nine zero-dep packages) requires a green `main`, the marid#40 precompile gate, `bun test` over `web/`, and the three still-open rulings D67 (marid#21), D69 (marid#23) and D72 (marid#26). As of 2026-10-06 `main` is red on nine checks (see [[CI-and-Operations]]), so the date is at risk.
- **D55.** The whole family submits as one coherent set after D56 and D57. Both landed 2026-09-22 in PR #41.
- **D59.** In-toto attestation wires in the same PR that cuts the first tag, attesting both the tag tarball digest and the git tree hash. No tag exists yet.
- **D53.** The monorepo is canonical; the satellites are publish targets or retired. See [[Ecosystem]] for where that ended up.

## Known stale statements in the sources

- `docs/marid-roadmap.adoc` and `docs/FRAMEWORK-ALIGNMENT.adoc` name `packages/ArangoDB/`; read as `packages/MaridArango/` (renamed 2026-09-22).
- `docs/FRAMEWORK-ALIGNMENT.adoc` cites an `ANCHOR.a2ml` file. No `.a2ml` file exists in the repository; the machine-readable anchors are `.deed` files under `.machine_readable/`.
- `docs/audits/gate5-release-review.adoc` declares all gates complete. It is marked superseded and must not be cited as status.
- The roadmap's MARID-001..007 milestone identifiers predate the recovery plan and are not tracked as issues.

## Related pages

[[Charter]] · [[Evidence]] · [[Decisions]] · [[CI-and-Operations]] · [[Packages]]
