<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000014
parent: 6d617269-6400-7000-8000-000000000001
position: 130
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Ecosystem

The repositories, companions and estate dependencies around the Marid hub, and where each one stands as of 2026-10-06. Package-level detail is on [[Packages]]; the rulings that shaped this layout (D53, D54, D66, D119) are on [[Decisions]].

Back to [[Home]].

## The hub

`metadatastician/marid` is the canonical source for every Marid package (D53, arm A). It was created on `hyperpolymath` and transferred to the `metadatastician` organisation on 2026-09-22 (D54), where it inherits the org ruleset layer (Estate Baseline, EstateBranching, EstateTagging, EstatePushing). The old `hyperpolymath/marid` URL redirects.

| fact | value (measured 2026-10-06) |
|---|---|
| Visibility | public, not archived |
| GitHub wiki | disabled (`has_wiki: false` in `.github/settings.yml`); this notebook lives in-repo under `docs/wikis/` |
| Open issues | 26 (16 at transfer) |
| Default branch | `main`, red on nine checks; see [[CI-and-Operations]] |
| Local clone | `developer/meta-repos/WEB/marid/marid` (SSH remote); one worktree `developer/worktrees/marid-berrywiki` |

## The eighteen satellites

On 2026-09-19 an automated fan-out published eighteen standalone repositories in a seventy-second window: thirteen Julia packages (`MaridIR.jl`, `MaridCodec.jl`, `MaridCore.jl`, `MaridTransport.jl`, `MaridOpenAPI.jl`, `MaridRPC.jl`, `MaridGraphQL.jl`, `MaridStorage.jl`, `ArangoDB.jl`, `MaridControl.jl`, `MaridLive.jl`, `MaridCRDT.jl`, `MaridRaft.jl`) and five JavaScript-side repositories (`marid-client`, `marid-react`, `marid-vue`, `marid-elements`, `marid-relationship-explorer`). They were frozen extracts of the hub's `packages/` and `web/` trees; the hub carried on receiving commits and the two copies diverged within two days.

Their history since:

| date | event |
|---|---|
| 2026-09-21 | CodeQL added to all eighteen so the org `code_scanning` rule could be satisfied |
| 2026-09-22 | all eighteen transferred to `metadatastician` (D54); hub last |
| 2026-09-22 | D53-A ruled: hub canonical, satellites become publish targets or are retired |
| 2026-10-05 | D119 ruled the satellites **archived**; the owner's branch-consolidation pass instead **deleted** them from GitHub. All eighteen now return 404 |

So the satellites no longer exist on GitHub. The deviation from D119 (deleted rather than archived) is recorded on [[Decisions]] as an open owner question.

### Where the satellite clones are

Measured 2026-10-06 by remote URL, not directory name, over `developer/{hyper-repos,meta-repos,worktrees}` to depth 7 and `developer/{archive,llm-coding-configs}` to depth 7. Positive control: the same filter finds the hub clone.

| clones | location | state |
|---|---|---|
| 13 Julia (incl. `ArangoDB.jl`) | `developer/archive/2026-10-05-misfiled-clone-dedupe/marid-standalone-snapshots/` | each on `main`, 0 unpushed commits |
| 5 JavaScript-side | `developer/archive/2026-10-05-branch-consolidation/retired-clones/meta-repos/WEB/marid/` | each on `main`, 0 unpushed commits |
| stale hub copy | `developer/archive/2026-09-30-root-sweep/docs/marid-review.PU0b9t/marid` (remote still `hyperpolymath/marid`) | review copy, superseded |

Both archive directories carry a README naming them safe to delete once the owner has reviewed them. Because the GitHub repositories are gone, **these clones are the only surviving copies of the satellites' own commit histories**. The content itself is in the hub, which was always ahead, but the satellite commits (including the 2026-09-21 CodeQL additions and the `RelationshipExplorer` fix `ab953cf`) exist nowhere else. The archive directories should not be deleted before the owner decides whether that history matters. Nothing else named like a satellite exists under `developer/` to depth 8; the `_MARID _SET` directory that held them until 2026-10-05 no longer exists.

Horizon of this measurement: paths under `/home/hyperpolymath/developer` only; mirrors on Codeberg, GitLab, Bitbucket, Disroot, Gitea or SourceHut were not probed (the hub's `mirror.yml` has never pushed, so none is expected).

## Companion projects

- **`http-capability-gateway`** (Elixir). The governance sidecar that enforces the Verb Governance Spec in front of the Marid HTTP service. MaridIR emits its DSL v1 policy; the paired fix for Marid's strict-policy tests merged there as `#112`. ADR-0007 records the relationship. See [[Architecture]] and [[Deployment]].
- **`rsr-template-repo`** (`hyperpolymath`). The hub was scaffolded from it on 2026-09-18 with `just repo-init julia-library`; its forty-odd workflows, rulesets JSON, and `.machine_readable/` layout come from there. The satellites were not template-derived and had one hand-rolled `ci.yml` each.
- **`standards`** (`hyperpolymath`). Source of the reusable workflows the hub calls (governance, hypatia-scan, estate audit, docstring scanner), the ruling ledger (`standards#787`) and the `.deed` grammar. Several hub gates fail today because of upstream state here (marid#31, #36, #38).
- **`cicd-suite`** and **`cicd-squabbler`** (`hyperpolymath`). The estate formatting gate that fixes the wiki directory names, and the `squabble verify-satisfied` PR-done checker.
- **`berrywiki`** (`metadatastician`). The notebook format and `berrywiki check` / `berrywiki sidebar` tooling this page set is validated with. Clone at `developer/meta-repos/KNOW/berrywiki`.

## Publication targets (none live)

| target | name | state |
|---|---|---|
| Julia General | thirteen packages, nine zero-dep first | not registered; D117 date 2026-10-14 |
| npm | `marid-client`, `marid-react`, `marid-vue`, `marid-elements` (scoped vs unscoped still a D58 question) | not published; names free as of 2026-09-19 |
| GitHub Releases / tags | hub | zero tags, zero releases; D59 attestation wires at the first tag |
| GitHub Pages | hub `pages.yml` | workflow skipped on `main`, `has_pages=false` |
| Forge mirrors | six forges via `mirror.yml` | never pushed (marid#32: twelve of thirteen secrets never existed) |

## Known stale statements in the sources

- `docs/audits/recon-2026-09-19.adoc` and `docs/audits/evidence-ledger.adoc` still write `github.com/hyperpolymath/marid`; the repository has been `metadatastician/marid` since 2026-09-22 and the old URL only redirects.
- The same recon reports "zero open issues" across the family; the hub has 26.
- `docs/audits/recon-2026-09-19.adoc` describes the satellites as live repositories; they were deleted on 2026-10-05.
- Any source naming `ArangoDB.jl` or `packages/ArangoDB` means `packages/MaridArango` (renamed 2026-09-22, UUID unchanged).
- Earlier session records placed the satellite clones under `hyper-repos/_JULIA_LIBRARIES _SET/_MARID _SET/`; that was true until 2026-10-05, when they were moved to the two archive directories above.

## Related pages

[[Packages]] · [[Web-SDKs]] · [[Decisions]] · [[Deployment]] · [[Governance]]
