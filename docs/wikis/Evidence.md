<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000009
parent: 6d617269-6400-7000-8000-000000000001
position: 80
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Evidence

What has been proven about Marid, how it was measured, and what remains unproven. Everything on this page is drawn from `docs/audits/`; the ledger there is authoritative and this page is a summary. Where the two differ, the ledger wins. For the decisions the evidence tests see [[Decisions]]; for where the program stands see [[Roadmap]]; for the hosted CI picture see [[CI-and-Operations]].

## 1. The evidence ledger and why it supersedes the gate audits

`docs/audits/evidence-ledger.adoc` (updated 2026-09-19) is the acceptance evidence ledger for the program. It opens with four statements that govern everything else:

- It supersedes unqualified readiness assertions in the historical Gate 1, 3, 4 and 5 audits. The brief and charter requirements are unchanged.
- CLADE's `incubating` phase remains authoritative; STATE is corrected to experimental.
- No package, release or deployment is accepted solely because unit tests pass.
- Thirteen prototypes exist; persistence, protocol and browser acceptance remain unproven. No fabricated percentage is used to declare readiness.

The reason it exists: the initial reconnaissance of 2026-09-19 (`docs/audits/recon-2026-09-19.adoc`) found that `gate5-release-review.adoc` asserted all gates complete and production-ready while the code at that revision had an in-memory mock where the Arango client should be, a storage adapter that silently delegated to memory, no HTTP listener in the transport package, a stub GraphQL executor and placeholder strings in the binary export endpoints. The gate audits were not deleted (they are retained for provenance) but each of `gate1-spikes.adoc`, `gate3-packages.adoc`, `gate4-assembly.adoc` and `gate5-release-review.adoc` now carries a WARNING block at the top reading: "Historical implementation report, not current gate acceptance. Its readiness claims are superseded by the evidence ledger. Mock/unit coverage must not be interpreted as independent interoperability."

The ledger is also included verbatim into `docs/audits/ordered-checkpoints-2026-09-19.adoc`, the delivery report for the three ordered checkpoints, which says of itself: "The ledger below is authoritative for the changed working tree."

## 2. Brief §8 release acceptance ledger

Reproduced from the ledger. The wording of the Acceptance column is the ledger's own and must not be upgraded.

| Requirement | Current evidence | Acceptance |
|---|---|---|
| Public API and supported feature/version matrix | Prototypes and recon inventory; exact unsupported features described | Partial |
| Unit tests | All thirteen package suites and browser shims executed in prior recon | Unit coverage only |
| Native protocol/database integration | Native gateway policy pipeline tested; persistence and main adapters still prototypes | Not release-accepted |
| Failure/resource cleanup | Generator/CLI rejection tests; socket tests recorded at checkpoint 2 when executed | Partial |
| Runnable example | Relationship explorer is in-memory; live unary example added at checkpoint 2 | Not a persistent reference app |
| Licensing/notices | MPL/CC mapping present; exact Arango release/edition audit not established | Pending human/exact-version audit |
| Reproducible installation | Runtime pins plus local-package bootstrap; `bootstrap.jl` now instantiates before resolving, and all four bootstrap consumers succeed in isolated empty depots | Offline-verified; hosted CI still decides |
| Julia/platform CI | Existing 1.10/1.11 Ubuntu unit matrix; hosted failures remain | Pending hosted verification |
| Unsupported features | Explicit in recon, this ledger and package docs | Documented, not implemented |
| Cold/warm/memory/cancellation benchmarks | Small-slice measurement may be recorded, no full release baseline | Pending |

The ledger adds, between checkpoints 1 and 2: "No ArangoDB, gRPC, MCP, GraphQL execution or browser release gate is waived."

## 3. Ordered checkpoints

The owner ordered three checkpoints in sequence: evidence and CI repair, then a real IR-driven HTTP/JSON path, then the strict gateway correction. Each is recorded in the ledger with the commands executed and the counts measured. A fourth section records the repair of `main` after the squash of PR #1.

### Checkpoint 1: evidence and CI repair

Implemented and evaluated before any endpoint work.

What changed:

- README, the Arango README and STATE corrected; historical audits prominently marked superseded.
- Julia 1.10.10 and Bun 1.4.2 pinned as local baselines. AffineScript compilation is still a feasibility blocker; no unverified compiler version is invented.
- Missing top-level `permissions:` added on the Julia and DCO workflows; uncovered action refs replaced with immutable revisions already verified in the prior recon.
- Official `gh-actions-lock` v0.1.6 `--verify-local` passes, as does the local pinning checker. Bare-SHA traceability warnings are retained. Remote re-resolution requires a GitHub token and was not performed; no lockfile was edited by hand.
- The required-file gate accepts single-source compatibility symlinks at root for GOVERNANCE and MAINTAINERS and an architecture entry point under `docs/`; the allowlist documents why the aliases exist. No governance prose is duplicated.
- The exact pinned required-files checker executed locally with repository owner set; all presence and substance checks pass. The workflow SPDX/permissions check passes.
- A password example was changed to an environment lookup. It was demonstration text, not a verified leaked credential. Fixed-template `innerHTML` parsing was replaced with DOM construction; it was not shown to accept attacker HTML. No security scanner rule was disabled and no finding was blanket-suppressed.
- Existing Bun shim and unit tests pass; this is not real-browser acceptance.

External limitations the ledger lists as "not green results":

- Hosted checks cannot be rerun until an authorized push or PR.
- The CodeQL startup failure still needs GitHub check and configuration diagnostics.
- Pages requires owner verification and enabling of the Pages Actions site; no account settings were changed. Sonar's exit-1 cause needs scanner logs, project and token verification; no claim is made that automatic analysis is configured.
- Full remote action re-resolution and the estate Hypatia rerun were not executed. Offline coverage and local source corrections do not replace them.

### Checkpoint 2: real IR-driven HTTP/JSON

What changed: JSON3 encoding and decoding with q-value and specificity negotiation; an HTTP.jl bounded unary listener; an optional MaridCore Codec/Transport extension; all-or-nothing IR method binding; root and nested-parameter routing fixes; explicit lifecycle flags and sanitized 500 responses. A new example at `examples/http_json` uses one descriptor for both routes and policy generation.

Executed with Julia 1.10.10:

| Command | Measured result |
|---|---|
| `scripts/bootstrap.jl examples/http_json`, then `examples/http_json/test/runtests.jl` | 38 assertions passed across real HTTP sockets, curl and a raw chunked request. Covers 400/404/405/406/413/415/500/503/504 behaviour, Unicode and quote JSON round trip, q=0, mutation-count protection, root and nested paths, shutdown, and application error redaction. |
| Thirteen independent package suites after bootstrapping | Pass. Codec adds twelve wire/negotiation assertions. |

The ledger's qualifier: "These are not ArangoDB, real-browser or arbitrary-stream tests." CI now instantiates local package dependencies explicitly and contains a separate real-HTTP job; hosted execution is unverified. The example README states the precise resource and lifecycle limits; no full production transport acceptance is asserted.

### Checkpoint 3: strict gateway and actual network path

Implemented after the real HTTP checkpoint, in both repositories, locally only. Marid retains explicit legacy globals and adds opt-in `--deny-by-default` / `gateway_profile=:strict`. Strict policy is native DSL v1 with empty globals; the unpatched upstream rejects it. At the time, `test/interop/gateway-strict.patch` recorded the paired changes against gateway revision `19b343c1e9b7c61668c60887369783d12a486f41` (the patch was later deleted; see the follow-up below).

Gateway-side changes: the gateway distinguishes unmatched paths from matched paths with forbidden verbs; exact path precedence and ambiguous-regex denial are tested; retired main handles cannot use a new regex companion; invalid exposure strings and non-string verbs reject; body limits, raw JSON bytes, repeated response header values, no redirect following and no automatic retries are covered. Two pre-existing plugin syntax errors, policy-load logging of `:ok`, and missing application-lifetime ETS initialization were necessary compile and startup repairs. Plugin security behaviour has not been validated by those syntax repairs.

Executed with Julia 1.10.10, Bun 1.4.2, Elixir 1.19.4 / OTP 27:

| Command | Measured result |
|---|---|
| All thirteen package suites rerun after the changes | 385 assertions pass (prototype tests do not prove persistence). MaridIR accounts for 79; strict and legacy CLI goldens pass. Direct HTTP/JSON tests remain 38/38. |
| `elixir test/interop/capability_gateway.exs <patched-gateway>` | Native loader, validator, compiler and lookup pass, including explicit legacy unknown-path fallback and strict denial. This test alone is not a proxy test. |
| Eight targeted gateway files | 6 properties + 66 tests, zero failures. Includes 31 compiler/validator/strict tests and four real-upstream wire tests. |
| `bash test/interop/run_http_gateway.sh <patched-gateway>` | 7 tests / 47 Bun assertions pass. Full application starts from generated IR policy; real HTTP goes through Cowboy/Req to Julia HTTP.jl/Core/JSON3. Allowed echo bytes roundtrip; missing verbs and unknown or near-miss paths deny; forged internal trust stays untrusted; 400/406/413/415 are preserved; only the valid echo increments its in-memory mutation count. Stopping the backend yields 502; policy denial still works without it. The synthetic internal probe contains no actual private data. |
| `mix test --seed 1` on the patched gateway | 12 properties, 263 tests, 15 failures. Baseline with only the two required plugin compile repairs: 12 properties, 253 tests, 19 failures. All 15 patched failure names reproduce on that baseline at the same seed. They are NOT waived or hidden as a green full-suite result. Failures include malformed fuzz-property declarations, a Plug Host-header test, management-route/stealth expectations and shared audit-buffer test state. Audit-path tests separately pass (2/2); persistent auditing is still unaccepted. |

CI applies the paired correction to an immutable gateway checkout, runs native policy plus targeted regression and wire tests, and starts the actual network runner. It explicitly does not claim a green full gateway suite. Hosted CI remained unrun at the time of writing. The authoritative local logs and baseline comparison accompanied the delivery.

### Follow-up: main after the #1 conflict resolution

The squash of PR #1 (`39d250a`) kept both sides of every clash, so `main` inherited two incompatible assumptions about one exported name: `packages/MaridIR/test/runtests.jl` still drove main's `capability_spec.jl` API (`emit_capability_spec(svc_cap)` with implicit `GET`/`POST` globals) while `MaridIR.jl` included only `capability.jl`, whose `global_verbs` is required. Result: the MaridIR matrix cells failed with `UndefKeywordError` at `runtests.jl:100`. The same split explained the `CLI & Emitters` failure (the job invoked a CLI form the merged parser rejects, against a service file the emitter cannot resolve, grepping the other emitter's shape) and the `MaridCodec`/`MaridTransport` cells (the new `scripts/bootstrap.jl` called `Pkg.resolve()` over a complete committed `Manifest.toml`, which needs a General registry that a fresh CI depot has not got).

Executed with Julia 1.10.10 against the repaired tree:

| Check | Measured result |
|---|---|
| MaridIR | 21 + 58 assertions pass |
| `examples/http_json` | 30 + 8 assertions pass |
| `MaridCodec` | 4 + 12 assertions pass |
| `MaridTransport` | 29 assertions pass |
| Each bootstrap consumer in its own empty `JULIA_DEPOT_PATH` | Succeeds. Two of them failed there before the change, which is the evidence this fix rests on rather than a passing local run. |
| `benches/marid_bench.sh json`, `test/interop/capability_cli.sh`, the repository-map determinism test, the root-shape, invisible character, placeholder, anti-pattern and adoc render gates | Pass |
| Both golden capability policies | Reproduce byte-identically from the emitter |
| `.a2ml` files | Zero remain, so `35aff92`'s purge is not undone by the repair |

The gateway side moved too. `test/interop/gateway-strict.patch` could not be applied by any git (`error: corrupt patch at ../test/interop/gateway-strict.patch:270`; four hunks, `webhook_hardener.ex`, `proxy.ex`, `proxy_wire_test.exs`, `strict_policy_test.exs`, declared line counts that did not match their bodies). The hosted failure was reported at the "Apply paired gateway changes" step, so every step after it had never actually run. Those changes are now upstream: the gateway merged them as `#112` (`c67c743c6c9f54c0482c1dd8d8dc151ff919551d`), whose per-file diff matches the patch's intent (the only residual difference, a local `parse_cidr/3` rewrite for `:inet.parse_cidr_address/1` in an inactive plugin, is the gateway repository's own concern). The patch was therefore deleted rather than repaired, CI pins the merged commit, and a grep assertion fails the job if that pin is ever moved below the correction. Whether the gateway's targeted `mix test` files pass at that pin is not verified in the ledger (no BEAM toolchain in that environment); the CI job is the first real run.

Not verified there, and claimed as not verified: Julia 1.11 (only 1.10.10 was available), the Elixir `policy-pipeline` step (no `mix`/`elixir` in the environment), and anything that needs the hosted runners. `build`, Sonar/SonarQube, `Canon lockstep` and `call-estate-audit` were already red on the parent commit `67c81f0` and are not addressed by that change.

## 4. Remaining blockers

As the ledger lists them at the end of checkpoint 3. None has been recorded as cleared in the sources read for this page.

- Existing dependency advisory output flags Cowboy 2.17.0, Cowlib 2.18.0 and Mint 1.9.3; no upgrade, revalidation or vulnerability waiver was performed.
- Inactive plugins reference unsupported `Plug.Conn.get_private/2` and `:inet.parse_cidr_address/1`. Do not enable them as validated security controls.
- No container engine, production image build, TLS/mTLS acceptance, external management isolation, backend bypass proof, rollout/rollback or resource baseline.
- Main/regex association is corrected, but lifecycle/reload concurrency and dynamic table atom lifetime are not production-proven. Proxy response buffering is not streaming or a heap quota; general cancellation remains a release blocker.
- Real DB and transactions, durable audit, browser and protocol acceptance are still behind the ordered checkpoint review. Charter acceptance requirements are unchanged.

The ordered-checkpoints report adds, for later phases: "Real persistence, browser and protocol acceptance remain gated. Security advisories, full-suite failures, hosted CI and container/identity/rollback acceptance must be resolved or explicitly reviewed before advancement."

## 5. The other audits

| File | Date | What it established | Status |
|---|---|---|---|
| `docs/audits/README.adoc` | undated | Defines what Gate 0 must produce (`feasibility.adoc`, `licensing.adoc`), the `.adoc` spelling rule, and the rule that every claim carries its source and date checked. | Current as to conventions; its closing status line is stale (see below). |
| `docs/audits/feasibility.adoc` | 2026-09-19 | Gate 0 integration matrix for ArangoDB HTTP client, HTTP/1.1 transport (`HTTP.jl`), gRPC/HTTP/2 (defer to Phase 8, launch with MaridRPC), GraphQL (`GraphQLite.jl` plus own SDL emitter), Cap'n Proto and Bebop (codecs only), and the AffineScript/Bun browser client. Registry check: all fourteen package names available and unregistered. Recommendation: proceed to Gate 1 spikes. | Standing Gate 0 input; not superseded by the ledger, but its ArangoDB package naming and `ANCHOR.a2ml` citation are stale (see below). The AffineScript blocker it monitored is still open per the ledger. |
| `docs/audits/licensing.adoc` | 2026-09-19 | Dual-license architecture (MPL-2.0 for code, CC-BY-SA-4.0 for documentation, MPL-2.0 for code snippets in docs), a dependency license review (all MIT or MPL-2.0, ArangoDB server Apache-2.0 over the network), the clean-room boundary against Genie.jl, generated-code policy, DCO and SPDX hygiene. Signs Gate 0 licensing off as satisfied. | Mapping stands. The ledger qualifies it: "exact Arango release/edition audit not established", acceptance "Pending human/exact-version audit". |
| `docs/audits/gate1-spikes.adoc` | 2026-09-19, Julia 1.10.5 | Four disposable spike suites under `test/spikes/` (ArangoDB HTTP wire framing, GraphQL SDL and introspection, binary codec framing, JSON-RPC 2.0 and MCP): 34 assertions passed (12 + 12 + 6 + 10). Declared the program cleared for Gate 2. | Marked superseded by the ledger. The recon notes the GraphQL spike explicitly calls `execute_mock_query` and that codec self-roundtrips do not establish foreign-runtime interop. |
| `docs/audits/gate3-packages.adoc` | 2026-09-19 | Reported nine Phase 1 to 3 packages implemented with standalone `Project.toml` manifests and "100% passing test suites". | Marked superseded by the ledger (WARNING block in header). |
| `docs/audits/gate4-assembly.adoc` | 2026-09-19 | Reported browser client packages, framework wrappers and the `relationship_explorer` reference app as implemented, integrated and verified. | Marked superseded by the ledger (WARNING block in header). The ledger records the explorer as in-memory and the browser tests as shims. |
| `docs/audits/gate5-release-review.adoc` | 2026-09-19 | Release audit across support matrix, security and failure behaviour, licensing, documentation, build reproducibility and registration order, validated against Julia 1.10.5. | Marked superseded by the ledger (WARNING block in header). This is the "100% MVP" claim the ledger exists to correct. |
| `docs/audits/recon-2026-09-19.adoc` | 2026-09-19 | Initial reconnaissance at Marid `96cfea4` and gateway `19b343c`: repository map per package with observed gaps, zero open issues/PRs/releases at inspection, hosted CI failures at the same SHA (required-files gate, actions lockfile, Hypatia critical finding, Pages, Sonar, CodeQL startup failure), sixteen local findings R01 to R16 (P0 to P2), two reproduced bugs (`swap_snapshot!` MethodError, root route registration), the native emitter and CLI change with 55 new assertions (370 total across thirteen packages, 28 explorer, 13 Bun tests / 29 expectations), and a bounded compose recipe. | Retained for provenance; its own IMPORTANT block says the ordered checkpoints and ledger are authoritative and its failure counts predate them. |
| `docs/audits/ordered-checkpoints-2026-09-19.adoc` | 2026-09-19, note added 2026-09-20 | Delivery report for the three checkpoints: summary table (38 real-socket assertions; 385 package assertions; 6 properties + 66 targeted gateway tests; 7 tests / 47 assertions on the real roundtrip; full gateway suite not green with 15 failures reproducing on baseline), the delivery artifacts (`marid-capability.patch`, `gateway-strict.patch`, `marid-delivery.zip`, `README.txt`), and the 2026-09-20 note that the gateway merged the correction as #112 so Marid's patch copy was deleted and CI pins that commit. Includes the ledger, the compose guide and the recovery plan. | Current wrapper; the ledger it includes is the authoritative part. |

## Known stale statements in the sources

Recorded rather than silently corrected:

- `docs/audits/README.adoc` ends with "Status: Gate 0 not yet started; no audit documents exist yet." Nine audit documents exist in the same directory, including both Gate 0 deliverables the README names.
- `docs/audits/feasibility.adoc` and `docs/audits/recon-2026-09-19.adoc` name the Arango client `ArangoDB.jl` at `packages/ArangoDB/`, and the recon's repository map has a row headed "ArangoDB". The directory is now `packages/MaridArango/` and the package is `MaridArango` (UUID `719c9fe8-89eb-588d-a237-0159f38ee2e4`, unchanged). The feasibility registry check for the name `ArangoDB` therefore refers to a name the project no longer intends to register.
- `docs/audits/recon-2026-09-19.adoc` links the inspected tree, Actions runs and API endpoints under `github.com/hyperpolymath/marid` and `api.github.com/repos/hyperpolymath/marid`. The repository is `github.com/metadatastician/marid`. The SHAs cited (`96cfea4c8eac855263bcfb47ca9f53fe7a893f34`, run ids 35433279958 to 35433280923) remain valid identifiers of what was inspected; only the owner segment of the URLs is stale. The gateway URL under `hyperpolymath/http-capability-gateway` is a different repository and is not affected.
- `docs/audits/feasibility.adoc` cites estate policy as `ANCHOR.a2ml`. Zero `.a2ml` files exist in the repository (confirmed locally while writing this page: `find . -name '*.a2ml'` returns nothing outside `.git`); the format was replaced by `.deed`. The ledger's own statement "Zero `.a2ml` files remain" is consistent with this.
- `docs/audits/ordered-checkpoints-2026-09-19.adoc` says "All changes are local, uncommitted and unpushed." The ledger's follow-up section describes the squash of PR #1 as `39d250a` on `main`, so the work has since landed; the sentence describes the state at delivery, not now.
- The ledger's checkpoint 3 section says `test/interop/gateway-strict.patch` "records the paired changes"; its own follow-up section records that the file was deleted and replaced by a pin on the merged gateway commit. Both are true of their respective moments; `ls test/interop/` today shows no patch file.
- `docs/audits/gate1-spikes.adoc` and `docs/audits/gate5-release-review.adoc` report validation under Julia 1.10.5; the ledger's pinned local baseline is Julia 1.10.10. This is a historical difference rather than an error, but no result on this page under 1.10.5 should be read as current.
