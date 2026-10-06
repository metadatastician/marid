<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000013
parent: 6d617269-6400-7000-8000-000000000001
position: 120
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# CI and Operations

What runs on every push and pull request, how the pinned action set is kept honest, which local scripts the gates call, what the `Justfile` offers, and the handful of failures that recur. The rules for agents are in `AGENTS.md`; the governance that decides what is required is on [[Governance]]; what the gates have actually proven is on [[Evidence]].

## The workflow set

`.github/workflows/` holds 39 workflow files plus three non-workflows: `actions.lock` (the pinned action set, below), `README.adoc` (why some workflows look duplicated) and `e2e.yml.template`, whose first line says it is "a scaffold, not a workflow".

| File | `name:` | Triggers |
|---|---|---|
| `build-notification.yml` | BoJ Server Build Trigger | push to `main`/`master`; dispatch |
| `capability-spec.yml` | Native Capability Spec | push to `main`; pull_request; dispatch |
| `codeql.yml` | CodeQL Security Analysis | push and pull_request on `main`/`master`; monthly cron (1st, 06:00 UTC) |
| `dco.yml` | DCO Sign-off Enforcement | pull_request (opened, synchronize, reopened); dispatch |
| `deed-validate.yml` | 🟡 CHECK: DEED Manifest Validation | pull_request (all branches); push to `main`/`master` |
| `dependabot-automerge.yml` | Dependabot Auto-Merge | pull_request (opened, reopened, synchronize) |
| `docker-build.yml` | container build | pull_request on `build/container/**`, `build/just/container.just`, the workflow file; push of `v*` tags; dispatch |
| `dogfood-gate.yml` | Dogfood Gate | pull_request (all branches); push to `main`/`master` |
| `dogfood-summary.yml` | ℹ️ ADVISORY: Dogfooding Compliance Scorecard | pull_request (all branches); push to `main`/`master` |
| `dot-wellknown-enforcement.yml` | Well-Known Standards (RFC 9116 + RSR) | push and pull_request on `www/.well-known/**`, `www/tests/**`, `www/schemas/**`, `.well-known/**`, `security.txt`; weekly cron (Mon 09:00 UTC); dispatch |
| `eclexiaiser-validate.yml` | 🟡 CHECK: Eclexiaiser Manifest Validation | pull_request (all branches); push to `main`/`master` |
| `empty-linter.yml` | 🔴 GATE: Invisible Character Detection | pull_request (all branches); push to `main`/`master` |
| `estate-rules.yml` | Estate Rules | push to `main`; pull_request |
| `governance.yml` | Governance | push and pull_request on `main`/`master`; dispatch |
| `groove-check.yml` | 🟡 CHECK: Groove Protocol Compliance | pull_request (all branches); push to `main`/`master` |
| `guix-policy.yml` | Guix Package Policy | push to `main`/`master`; pull_request |
| `hypatia-scan.yml` | Hypatia Security Scan | push to `main`/`master`/`develop`; pull_request on `main`/`master`; weekly cron (Sun 00:00 UTC); dispatch |
| `julia-ci.yml` | Julia Packages CI | push and pull_request on `main`; dispatch |
| `k9-validate.yml` | 🟡 CHECK: K9 Contract Validation | pull_request (all branches); push to `main`/`master` |
| `labels.yml` | Labels | dispatch; push touching `.github/labels.json`; monthly cron |
| `label-triage.yml` | Label Triage | issues (opened, reopened); dispatch with an `issue` input |
| `lock-sync-gate.yml` | Lock Sync Gate | dispatch; pull_request; push to `main` |
| `main-estate-audit.yml` | Central Estate CI/CD Audit | push and pull_request on `main`; workflow_call |
| `mirror.yml` | Mirror to Git Forges | push to `main`; dispatch |
| `ossf-best-practices.yml` | OpenSSF Compliance | push and pull_request on `main`; dispatch |
| `pages.yml` | GitHub Pages | push to `main`; dispatch |
| `push-email-notify.yml` | Push email notification | push to any branch |
| `quality.yml` | Code Quality | push to `main`/`master`; pull_request |
| `release.yml` | Release | push of `v*` tags |
| `rsr-compliance-canary.yml` | 🤖 Rhodibot - RSR Compliance Canary (the source name uses a long dash) | weekly cron (Mon 06:00 UTC); dispatch |
| `runtime-policy.yml` | Runtime Policy | push to `main`/`master`; pull_request |
| `rust-ci.yml` | Rust CI | push to `main`/`master`; pull_request |
| `scorecard.yml` | OSSF Scorecard | daily cron (04:00 UTC); dispatch |
| `secret-scanner.yml` | Secret Scanner | pull_request; push to `main` |
| `security-policy.yml` | Security Policy | push to `main`/`master`; pull_request |
| `sonarqube.yml` | SonarQube | push and pull_request on `main`/`master`; dispatch |
| `static-analysis-gate.yml` | Static Analysis Gate | pull_request (all branches); push to `main`/`master` |
| `web-ci.yml` | Web CI | push to `main` touching `web/**` or the workflow; pull_request; dispatch |
| `workflow-linter.yml` | Workflow Security Linter | push and pull_request touching `.github/workflows/**`; dispatch |

`.github/workflows/README.adoc` explains three apparent duplications that must not be "tidied away": Hypatia runs both standalone (`hypatia-scan.yml`) and inside `static-analysis-gate.yml`, whose `hypatia-scan` job is a required status check and feeds the gitbot-fleet learning pipeline; secret scanning is gitleaks in CI (`secret-scanner.yml`, via the standards reusable) and TruffleHog locally (`.githooks/scan-secrets.sh` from `.githooks/pre-push`), a two-tier design ratified by the owner on 2026-09-14; and CodeQL, SonarCloud and the panic-attack plus Hypatia gate each cover a different surface.

The Julia side is `Julia Packages CI`, whose `cli-and-emitters` job (Julia `1.10.10`) runs the compat checker below, verifies capability-spec generation through `./scripts/marid generate capability-spec` against `fixtures/capability/policy-strict.yaml`, and runs `benches/marid_bench.sh json`. The browser side is `Web CI`; see [[Web-SDKs]].

## `actions.lock`: the pinned action set

`.github/workflows/actions.lock` (304 lines, format `version: 'v0.0.2'`) is machine-generated by `gh actions-lock`; its header says "Do not edit by hand". Under `workflows:` it lists, per workflow path, the exact `owner/repo@ref` set that workflow may use (for example `codeql.yml` is locked to `actions/checkout@v7.0.1` and `github/codeql-action@2892aa5e19bbd11bc0cff5427e3b750a04d9e3c2`; `governance.yml` to `hyperpolymath/standards@da2c748a...`), and under `dependencies:` it records each ref together with the nested `uses:` that ref itself makes.

Operating rules:

- Regenerate it only with the tool, never by hand:

  ```bash
  gh actions-lock --no-narrow
  git add .github/workflows/actions.lock
  ```

- The tool's default fix mode de-pins SHA refs to floating tags. The `check-lock-sync.sh` fix text also warns that the tool "does NOT handle job-level reusable-workflow refs and it can de-pin bare SHAs to floating tags", so review the diff before committing.
- Drift is not cosmetic. `lock-sync-gate.yml`'s header records why: when the lock and the YAML disagree, GitHub refuses the run at startup, creates zero jobs, and reports only "This run likely failed because of a workflow file issue". Measured across 200 repositories on 2026-09-22, 39 had silently dead CI from this cause (standards#968).
- The lock is verified by `scripts/check-lock-sync.sh`, run by the `Lock Sync Gate` workflow. That workflow deliberately contains no `uses:` of its own (it checks out with `git` in a `run:` step) so it can never go stale against the very file it checks, and it has no `paths:` filter so a branch ruleset requiring it can never deadlock.

### What `scripts/check-lock-sync.sh` asserts

Exit 0 only when every clause holds; any violation exits 1; there is no warn-only mode. It needs `gawk` (3-argument `match()`), and probes for it rather than trusting the name.

| Clause | Assertion | Why it exists |
|---|---|---|
| 1 | Every `uses:` in a workflow is locked under that workflow's own path in the lockfile (job-level reusable-workflow refs included) | The basic sync check |
| 2 | Every lockfile entry is still referenced by its workflow (no orphans), and no lockfile key names a workflow file that no longer exists | Stale entries |
| 3 | Transitive closure: every ref named anywhere in the lockfile resolves to a top-level `dependencies:` record (no dangling edges) | A ref present but unresolvable is fatal at startup, while a ref absent entirely is harmless. Measured on cicd-squabbler 2026-09-22: two commits passed clauses 1 and 2 and `gh actions-lock --verify-local` while GitHub refused four workflows |
| 4 | Coverage: every workflow file has a key in the lockfile, including zero-`uses:` workflows, which take an empty list (`'.github/workflows/x.yml': []`) | Measured on verisimdb and blocky-writer 2026-09-22: a workflow with no `uses:` and no lock key was `startup_failure`; adding the empty entry fixed it |

It also fails on the `uses: $/...` corruption pattern. On failure it prints a four-step repair sequence (run the tool, add `dependencies:` records for dangling edges, collapse subpath pins such as `github/codeql-action/upload-sarif@sha` to `github/codeql-action@sha`, add empty-list keys for unlisted workflows). Owner and repo names in refs are compared case-insensitively; refs are not.

## Other check scripts the gates call

### `scripts/check-no-md-in-docs.sh`

Enforces "AsciiDoc by default for general docs": it exits 1 if any `.md` file exists under `docs/` that is not allow-listed, 0 otherwise, 2 on usage errors. As read, `ALLOWED=()` is empty and `ALLOWED_DIRS=("docs/berrywiki/")`. Run by `Estate Rules` as the step "AsciiDoc by default (no .md under docs/)". A sibling step, `scripts/check-adoc-renders.sh`, then checks that every tracked `.adoc` actually parses under asciidoctor `2.0.26`, because the extension check alone passes a Markdown body renamed to `.adoc`.

### `scripts/gen-repo-map.sh`

Generates `docs/architecture/REPOSITORY-MAP.adoc` from the tracked tree plus the annotations in `.machine_readable/root-allow.txt` (the same allowlist `scripts/check-root-shape.sh` enforces). The header explains why it is generated: the repo once carried five hand-written maps and none was accurate. It exports `LC_ALL=C` because `sort` is locale-dependent and the first CI run caught the map differing between environments; `Estate Rules` therefore runs `tests/shape/repo_map_determinism_test.sh` before diffing. CI fails on drift with the message "REPOSITORY-MAP.adoc is stale - run 'just repo-map'". Regenerate with:

```bash
just repo-map
```

`just validate-repo-map` performs the same diff locally and restores the committed file on failure.

### `scripts/check-julia-compat.jl`

Asserts that every `dep` and `weakdep` of every package under `packages/` carries an upper-bounded `[compat]` entry (stdlibs included), and that each package's `julia` compat is bounded, below 2.0 and admits some 1.x. Acceptance criterion: marid#22 (D68). The predicate `_has_upper_bound` is lifted verbatim from RegistryCI.jl so the gate cannot drift from what the Julia General registry checks, and the header says it is deliberately stricter than AutoMerge, which currently skips stdlib compat. It self-tests against seven fixtures (six seeded defects plus one clean control) and exits 2 if any seeded defect goes undetected, 2 if `packages/` or any `Project.toml` is missing, 1 if any package fails, 0 otherwise. Wired into `julia-ci.yml` as the first step of the `cli-and-emitters` job:

```bash
julia --startup-file=no scripts/check-julia-compat.jl
```

## The `Justfile`

The root `Justfile` is the RSR standard template with Marid values (`project := "marid"`, `version := "0.1.0"`, `tier := "infrastructure"`). It imports optional modules from `build/just/` (`repo-init`, `container`, `groove`, `assess`, `validate`, `proofs`) and `build/contractile.just`; the `clean` recipe deliberately does not remove `build/` because those imports live there. Main recipes:

| Recipe | What it does |
|---|---|
| `default`, `help`, `info` | List recipes; show one recipe; print project, version, tier and the phase from `.machine_readable/descriptiles/marid_chora.deed` |
| `test`, `test-verbose`, `test-smoke` | All three run `./scripts/marid check` |
| `e2e`, `aspect`, `bench` | `tests/e2e.sh`, `tests/aspect_tests.sh`, `benches/marid_bench.sh` |
| `test-all` | `test e2e aspect bench readiness` |
| `quality` | `fmt-check lint test` |
| `ci` | `deps quality proof-check-all`; the comment says `proof-check-all` is fatal if any prover toolchain (idris2, lean, agda, coqc) is absent |
| `repo-map`, `validate-repo-map` | Regenerate the repository map; fail if it is stale |
| `claude-md`, `validate-claude-md` | Compile `CLAUDE.md` via `.machine_readable/arrival-pack/generate.sh`; fail if its generated region drifted |
| `coapt`, `coapt-reanchor`, `validate-coapt` | Coaptation receipt between descriptiles and contractiles; re-anchor basis; drift check |
| `docs`, `cookbook`, `man` | Generate `docs/just-cookbook.adoc` and `docs/man/marid.1` |
| `install-hooks` | Writes a pre-commit hook running `fmt-check`, `lint` and `assail` |
| `security`, `deps-audit`, `sbom`, `secret-scan-trufflehog`, `assail`, `maint-assault` | trivy, syft, TruffleHog and panic-attack wrappers (each skipped if the tool is absent) |
| `state-touch`, `state-phase` | Update `0-AI-MANIFEST.deed`'s `last-updated`; print the phase from `marid_chora.deed` |
| `changelog`, `changelog-preview`, `release-tag` | git-cliff into `CHANGELOG.adoc`; signed `v<version>` tag, pushed on its own because direct pushes to `main` are rejected |
| `guix-shell`, `guix-build` | `guix shell -D -f guix.scm`; `guix build -f guix.scm` |
| `doctor`, `tour`, `help-me`, `status`, `log`, `loc`, `todos`, `edit` | Diagnostics and utilities; `help-me` points to `https://github.com/metadatastician/marid/issues/new` |
| `intake-repo`, `checkpoint-change`, `verify-*`, `close-*`, `recover-repo`, `handover-*`, `session-help` | Thin wrappers over `./session/dispatch.sh` |
| `cloak`, `uncloak` | Hide or reveal dotfiles in Windows Explorer; no-ops on POSIX |

Several recipes are still the template's `TODO` stubs that only echo: `build`, `build-release`, `build-watch`, `fmt`, `fmt-check`, `lint`, `deps`, `readiness`, `run`, `install`. `quality` and `ci` therefore currently exercise only `test` (and, for `ci`, the proof gate).

## Operating rules from `AGENTS.md`

The repository `AGENTS.md` is short and operational. Read `PROJECT_BRIEF.md` before architectural changes; implement only the approved task or gate and do not widen scope or weaken acceptance criteria; prefer maintained dependencies over new protocol or runtime implementations; record architectural choices in `docs/adr/` and version-specific evidence in `docs/audits/`; no circular package dependencies; keep integrations optional; preserve third-party notices; do not publish, register packages, deploy or use paid services without approval; and report what was implemented, tested, not tested and blocked, never equating mocks or skipped tests with interoperability.

Repository-specific notes: general docs under `docs/` are AsciiDoc, with the brief's `docs/*.md` names mapped to `.adoc` equivalents; root shape is enforced by `.machine_readable/root-allow.txt` and new root entries need a justifying comment there; run `just repo-map` after adding, moving or deleting files; Julia packages live in `packages/` with one `Project.toml` each and intentionally no root `Project.toml`; `src/interface/` is retained RSR spine required by `just validate`, not Marid application code. A sandbox-repair note says a fresh agent session may lose files under `build/` and `verification/coverage/`, executable bits, and the `just` 1.40.0 and `nickel` 1.17.0 binaries, and gives the restore commands.

## `docs/troubleshooting.adoc`

The troubleshooting file is still the template: its two failure-mode entries are placeholders (`<error message or symptom>`), its `:revdate:` is `2026-MM-DD`, and its diagnostic toolkit names `just doctor`, `just version` and `just log-tail`. Of those, only `doctor` appears among the `Justfile` recipe names. The real recurring failures are recorded below until that file is filled in.

## Known recurring failures

1. **Dependabot bumps break the lock.** Dependabot rewrites `uses:` versions in the workflow YAML and cannot touch `actions.lock`; when such a bump merges without regenerating the lock, `Lock Sync Gate` and the governance lockfile check go red on `main`. Tracked as marid#35. The fix is always the same: run `gh actions-lock --no-narrow`, review the diff, commit the lock.
2. **Wiki content must be `.md`.** The estate formatting gate requires wiki content under `docs/wikis/` to be Markdown. The previous `docs/wikis/README.adoc` failed it, which is why this notebook exists as `.md` files. Note that `scripts/check-no-md-in-docs.sh` as read allow-lists `docs/berrywiki/`, not `docs/wikis/`; see the stale-statements list.
3. **`Canon lockstep` was a gate that could never pass, and has been removed.** The `canon-lockstep` job in `dogfood-gate.yml` fetched `canon.lock` from `hyperpolymath/standards` and then tried to fetch `.machine_readable/rsr-profile.a2ml` from this repository. No such file ever existed, so the job exited 1 on every run. Removed in the PR that closed marid#31; the dogfooding scorecard was never scoring it (its six inputs are DEED, K9, `.editorconfig`, Groove, VeriSimDB and eclexiaiser), so `MAX=6` is unchanged. If a canon/spine binding is wanted again it must read a file this repository actually ships (a `.deed`).
4. **Estate audit "Required Files Gate" does not name the file.** `main-estate-audit.yml` calls the reusable `hyperpolymath/cicd-suite/.github/workflows/main-estate-audit.yml` (pinned to `222b1d95...`) as job `call-estate-audit`; its `estate-audit` "Required Files Gate" fails without saying which required file is missing. Tracked as marid#38.

## Known stale statements in the sources

Flagged, not silently fixed.

- **`.a2ml` references.** `AGENTS.md` says `CLAUDE.md` "is generated from the `.a2ml` sources" and to "edit the `.a2ml` sources and regenerate". Zero `.a2ml` files exist in the repository; the descriptors are `.deed` files (`0-AI-MANIFEST.deed`, `.machine_readable/descriptiles/marid_chora.deed`), which is also what `just info`, `just state-touch` and `just state-phase` read.
- **(C) Stale owner URLs.** `docs/troubleshooting.adoc` sends readers to `https://github.com/hyperpolymath/Marid/issues`; the repository is `github.com/metadatastician/marid`, which is where the `Justfile`'s own `help-me` recipe points. The `Justfile` header still sets `OWNER := "hyperpolymath"`.
- **(A) Gate 0 wording.** `AGENTS.md` refers to "the Gate 0 assignment" in `docs/agent-launch.adoc` as a kickoff prompt; that is a historical pointer, but readers should not take it as a statement that nothing exists yet. See [[Roadmap]] for the current gate position.
- **Allow-list path.** `scripts/check-no-md-in-docs.sh` allow-lists `docs/berrywiki/` while the notebook lives in `docs/wikis/`; one of the two must change for `Estate Rules` to pass with these pages present.
- **Repair command wording.** The prompt-level rule for this repository is `gh actions-lock --no-narrow`; the fix text printed by `scripts/check-lock-sync.sh` names `gh actions-lock --no-migrate-local-actions` instead. Both agree that the tool is blind to job-level reusable refs and may de-pin SHAs.
- **`docs/troubleshooting.adoc`** points to `docs/architecture.adoc` and `SECURITY.md`; `AGENTS.md` maps the architecture document to `docs/marid-architecture.adoc` and the repository map is `docs/architecture/REPOSITORY-MAP.adoc`.
- Pattern (B) `packages/ArangoDB` was not found in the sources read for this page; the package is `packages/MaridArango`. See [[Packages]].
