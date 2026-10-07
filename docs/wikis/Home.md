<!-- berrywiki
id: 01a115aa-ca16-8134-837f-254d19a045bf
parent: null
position: 0
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Marid

Julia-first framework for web applications, APIs and reactive scientific dashboards: one service descriptor, many protocol bindings, a pure local routing data plane, and pluggable storage with ArangoDB as the flagship backend.

This BerryWiki notebook is the human-facing index; the repository's machine-readable state file (`.machine_readable/descriptiles/STATE`) is authoritative for automation, and `docs/audits/evidence-ledger.adoc` is authoritative for what has actually been proven.

## Status in one paragraph

Marid is **experimental**. Thirteen Julia packages and four browser SDKs exist as working prototypes whose unit suites pass locally (385 assertions across the thirteen packages at the last recorded run), but **no release gate is accepted**: persistence against a real ArangoDB, GraphQL and gRPC execution, and real-browser interoperability remain unproven. The earlier "Gate 5 production-ready" claim is superseded by the evidence ledger. See [[Roadmap]] and [[Evidence]].

## Pages

- [[Charter]]: mission, the twelve principles, non-goals, licensing, and the gated build order.
- [[Architecture]]: the request pipeline, the six core contracts, and the compatibility matrix.
- [[Packages]]: the thirteen Julia packages under `packages/`, what each does, and what is proven.
- [[Web-SDKs]]: the four `@metadatastician/marid-*` browser packages under `web/`.
- [[Roadmap]]: the six program gates, the charter phases, and where the program stands.
- [[Decisions]]: the seven architectural decision records.
- [[Evidence]]: the acceptance evidence ledger, audits, and ordered checkpoints.
- [[Deployment]]: the compose stack, the production guide, and what is and is not claimed.
- [[Onboarding]]: quick starts for users, developers and maintainers.
- [[Contributing]]: DCO, SPDX, clean-room discipline, and the review gates.
- [[Governance]]: maintainers, decision procedure, and the estate rulesets that bind the repo.
- [[CI-and-Operations]]: the workflow set, the `actions.lock` discipline, and the gates that fail most often.
- [[Ecosystem]]: the former satellite repos, the move to `metadatastician`, and the Julia General registration plan.
- [[Glossary]]: terms used across the notebook.

## Where the canonical documents live

| Question | File in the repository |
|---|---|
| What must be true for acceptance? | `PROJECT_BRIEF.md` (the brief, §1–§9) |
| In what order is it built? | `docs/MARID-FRAMEWORK.adoc` (the charter) |
| What has been proven, and how? | `docs/audits/evidence-ledger.adoc` |
| Where does every directory come from? | `docs/architecture/REPOSITORY-MAP.adoc` (generated; CI fails on drift) |
| How do agents work here? | `AGENTS.md`, `0-AI-MANIFEST.deed` |
