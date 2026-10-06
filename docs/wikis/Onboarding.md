<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000011
parent: 6d617269-6400-7000-8000-000000000001
position: 100
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Onboarding

Quick starts for the three human audiences and for AI agents, written from `docs/onboarding/QUICKSTART-USER.adoc`, `QUICKSTART-DEV.adoc`, `QUICKSTART-MAINTAINER.adoc`, `llm-warmup-dev.adoc`, `llm-warmup-user.adoc`, `docs/QUICKSTART.adoc`, `docs/agent-launch.adoc`, `docs/AI_INSTALLATION_GUIDE.adoc`, `mise.toml` and the quick-start section of `README.adoc`. Several of those quickstarts are still template text from `rsr-template-repo`; where a recipe they name does not exist in the `Justfile`, this page says so instead of repeating it.

## Pick your path

| You are | Start with | Then |
|---|---|---|
| A user who wants to run something | Toolchain pins below, then the `examples/http_json` run on [[Deployment]] | [[Packages]] for what each package does |
| A developer working on the packages | The developer section below | [[Contributing]] for DCO, SPDX and the review gates; [[Architecture]] for the seams you must not cross |
| A platform maintainer or packager | The maintainer section below | [[Governance]] and [[CI-and-Operations]] |
| An AI coding agent | "If you are an AI agent" below | `AGENTS.md`, `PROJECT_BRIEF.md`, then [[Roadmap]] |

## Toolchain pins

`mise.toml` is the local test baseline. Every tool name in it was checked against `mise registry` and resolved with `mise ls-remote` before being written.

| Tool | Pin | Note from `mise.toml` |
|---|---|---|
| Julia | `1.10.10` | Local test baseline pinned 2026-09-19; CI also covers Julia 1.11 |
| Bun | `1.4.2` | Bun is the JavaScript runtime and package manager |
| just | `latest` | The estate task runner; `mise [tasks]` is deliberately not used |
| Node, npm, yarn, pnpm, Deno | **ejected** | Removed 2026-09-19 (Deno per owner ruling 2026-08-26) |
| AffineScript | no pin | The browser language is AffineScript (JaffaScript face), consumed as `@hyperpolymath/affinescript` under Bun. Compiler selection and build remain unverified; `mise.toml` records "no fabricated pin" |

`README.adoc` adds that the AffineScript toolchain and build are not yet proven and remain a blocker.

## There is no root `Project.toml`

This is intentional (`README.adoc`; `PROJECT_BRIEF.md` section 3). Each Julia package under `packages/` has its own environment. To work in one package or example, bootstrap it:

```bash
julia --startup-file=no scripts/bootstrap.jl <project-directory>
```

`scripts/bootstrap.jl` reads every `packages/*/Project.toml`, walks the target project's `[deps]` transitively, `Pkg.develop`s the local Marid packages it finds by relative path, then runs `Pkg.instantiate()` first and falls back to `Pkg.resolve()` only if instantiation fails. The comment in the script explains why: a committed `Manifest.toml` is a complete source-pinned resolution, and resolving on top of it would demand a usable General registry in a fresh CI depot for no reason.

The thirteen packages present under `packages/` are `MaridArango`, `MaridCodec`, `MaridControl`, `MaridCore`, `MaridCRDT`, `MaridGraphQL`, `MaridIR`, `MaridLive`, `MaridOpenAPI`, `MaridRaft`, `MaridRPC`, `MaridStorage` and `MaridTransport`. See [[Packages]].

## Users

The README quick start is the one that matches the tree:

```bash
git clone https://github.com/metadatastician/marid.git
cd marid

# Check the repo satisfies the RSR shape:
just validate            # structure + metadata checks

# Read the contract before anything else:
#   PROJECT_BRIEF.md       # the product/engineering contract
#   AGENTS.md              # repository instructions for coding agents
#   docs/agent-launch.adoc # the agent launch prompts
```

Then run the unary HTTP/JSON example from [[Deployment]]: bootstrap `examples/http_json`, run its tests, start `server.jl` and `curl` `/api/echo`. That is the only runnable end-to-end slice the repository currently claims.

`just validate` runs `validate-rsr` and `validate-ai-install` (defined in `build/just/validate.just`). `just doctor`, `just tour` and `just help-me` exist and do what `QUICKSTART-USER.adoc` says (diagnostic, guided tour, pre-filled problem report). The recipes `setup`, `heal`, `stapeln-run`, `uninstall` and `run --help` named in that quickstart are not defined in the `Justfile` or its imports; see the stale list at the end.

## Developers

Tech stack (`QUICKSTART-DEV.adoc`): Julia for the backend packages in `packages/`; AffineScript (`.affine` sources compiled to typed WebAssembly) under Bun for the browser client in `web/`.

Environment:

```bash
# Option A: Guix
guix shell            # or: just guix-shell

# Option B: manual
git clone https://github.com/metadatastician/marid.git
cd marid
mise install          # Julia 1.10.10, Bun 1.4.2, just
```

Build and test a package in its own environment:

```bash
julia --startup-file=no scripts/bootstrap.jl packages/MaridCore
julia --startup-file=no --project=packages/MaridCore -e 'using Pkg; Pkg.test()'
```

Package unit tests live with their packages; cross-protocol suites live in `test/interop/`.

Recipes that exist in the `Justfile` and matter day to day:

| Recipe | What it is |
|---|---|
| `just build`, `just build-release` | Build |
| `just test`, `just test-all` | Tests; `test-all` adds `e2e`, `aspect`, `bench`, `readiness` |
| `just lint`, `just fmt`, `just fmt-check` | Static checks and formatting |
| `just quality` | `fmt-check lint test` |
| `just validate` | RSR shape and AI-install checks |
| `just repo-map`, `just validate-repo-map` | Regenerate and check `docs/architecture/REPOSITORY-MAP.adoc` (CI fails if stale) |
| `just doctor`, `just tour` | Self-diagnostic, guided tour |
| `just install-hooks` | Local git hooks (see [[Contributing]]) |

Invariants from `QUICKSTART-DEV.adoc` that must never be violated:

- Adapters must not depend on one another; `Marid` must not unconditionally load every adapter (`PROJECT_BRIEF.md` section 3).
- No replacement universal IDL: native schemas stay native.
- No arbitrary Julia evaluation from network messages; no Julia object deserialisation from untrusted clients.
- Mocks never prove interoperability. Every integration needs a real interop or database integration test.

Read the contractiles in `.machine_readable/contractiles/` (start with `must/`) before making changes. The repository map is generated: `docs/architecture/REPOSITORY-MAP.adoc`.

Before a PR: `just lint`, `just test`, and the checks on [[Contributing]] (DCO sign-off on every commit, SPDX headers, hooks). `QUICKSTART-DEV.adoc` also lists `just panic-scan`; that recipe does not exist.

## Maintainers

`QUICKSTART-MAINTAINER.adoc` is the RSR spine default and says so in its own note; its install paths, config location (`$XDG_CONFIG_HOME/marid/config.toml`, fallback `$HOME/.config/marid/config.toml`) and multi-instance layout are template defaults, not Marid-specific decisions. What is real in the tree:

```bash
git clone https://github.com/metadatastician/marid.git
cd marid
just build-release
just install            # depends on build-release
guix build -f guix.scm  # or: just guix-build
```

Container work goes through the `container-*` recipes (`container-build`, `container-run`, `container-up`, `container-down`, `container-sign`, `container-verify`, `container-push`) in `build/just/container.just`; the `stapeln-export` recipe named in the quickstart does not exist. Release and audit recipes: `just release-tag <version>`, `just changelog`, `just sbom`, `just security` (runs `deps-audit`), `just doctor`.

Licensing for anything you package: MPL-2.0 for code, CC-BY-SA-4.0 for docs (`QUICKSTART-MAINTAINER.adoc`, "Security Notes"; details on [[Contributing]]). Dependencies are declared per package in `Project.toml` `[deps]` with a `[compat]` closure.

The rulesets that bind `main` and tags are inherited from the `metadatastician` organisation; see [[Governance]].

## If you are an AI agent

`docs/AI_INSTALLATION_GUIDE.adoc` opens with a note minted 2026-09-18: this repository has already been instantiated from `rsr-template-repo` (julia-library archetype). Agents working **on** Marid should start with `PROJECT_BRIEF.md`, `AGENTS.md` and `docs/onboarding/QUICKSTART-DEV.adoc`. The rest of that guide records how the instantiation was performed, for provenance.

Orientation order from that guide:

1. `0-AI-MANIFEST.deed`, the universal AI entry point at the repository root.
2. `CLAUDE.md`, the generated arrival pack.
3. `.machine_readable/descriptiles/marid_chora.deed`, the current phase and repository deed.

Do not infer the repository's purpose from its name. If a fact is not written down, record it as `UNASSIGNED` rather than inventing it.

**The one trap worth stating up front** (`README.adoc` and the guide): do not set `RSR_NON_INTERACTIVE=1`. It stubs the shell builtin `read` globally, which also disables the `while read -r file` loops that drive token substitution. The run never terminates and substitutes nothing. Drive non-interactive runs by piping answers to stdin instead.

`docs/agent-launch.adoc` holds the operational prompts transcribed from the owner's program brief on 2026-09-18:

| Prompt | Use |
|---|---|
| Gate 0 kickoff | Feasibility, dependency and licensing discovery only: investigate ArangoDB HTTP client, gRPC, GraphQL, Cap'n Proto and Bebop options; verify against real repositories and licences; propose the dependency graph; produce the audits, architecture, compatibility and roadmap docs; break work into small issues; stop before production implementation |
| Bounded task | Implement one issue from the approved roadmap with a working implementation, a real interoperability or integration test, docs, dependency and licensing updates, the exact commands run, and remaining blockers. If a prerequisite is missing, report it rather than substituting a mock |
| Parallel workstreams | Integration lead, database, RPC, query, binary-schema and browser workers; one agent can run them sequentially; shared-contract changes go through the integration lead |

Where those prompts name `docs/*.md` paths, the estate rule applies: general docs under `docs/` are AsciiDoc (`docs/audits/feasibility.md` is `docs/audits/feasibility.adoc`).

The two `llm-warmup-*.adoc` files are thin: they point at `README.adoc` and `EXPLAINME.adoc`, state the licence as MPL-2.0, and list `just setup`, `build`, `test`, `doctor`, `heal`. Of those, `setup` and `heal` are not defined.

## Known stale statements in the sources

- `QUICKSTART-MAINTAINER.adoc` note: "Gate 0 not yet started. No Marid package exists to package, deploy, or maintain." Thirteen packages exist under `packages/` (pattern A).
- `QUICKSTART-DEV.adoc`: "At Gate 0 no `Project.toml` exists yet and there is nothing to instantiate" (pattern A); the project-structure tree says `packages/` holds "Six Julia packages (Marid + five integrations)" and names `packages/Marid`, which does not exist; the thirteen actual directories are listed above.
- `QUICKSTART-DEV.adoc` cites `0-AI-MANIFEST.a2ml` (twice) and `.machine_readable/bot_directives/methodology.a2ml`. Zero `.a2ml` files exist in the tree; the entry point is `0-AI-MANIFEST.deed` (pattern C, `.a2ml`).
- `QUICKSTART-USER.adoc` is unsubstituted template text: "Rsr Template Repo - See README.adoc for details." as the project description and "Rsr Template Repo started successfully." as expected output.
- Recipes named across the quickstarts and warmups that are not defined in `Justfile` or `build/just/*.just`: `setup`, `setup-dev`, `heal`, `llm-context`, `panic-scan`, `stapeln-run`, `stapeln-export`, `uninstall`, `install --portable`.
- `docs/QUICKSTART.adoc` describes cloning this repository as a template for a new project (`rm -rf .git`, `just repo-init`). The AI installation guide says instantiation has already happened; that quickstart is template residue, not Marid onboarding.
- `QUICKSTART-DEV.adoc` says exact toolchain versions "are pinned at Gate 2"; `mise.toml` pins Julia 1.10.10 and Bun 1.4.2 today.
- The `llm-warmup-*.adoc` files say "Part of hyperpolymath ecosystem"; `MAINTAINERS.adoc` records the GitHub owner as `metadatastician` (see [[Ecosystem]]).
- No `github.com/hyperpolymath/marid` URL or `packages/ArangoDB` path was found in the onboarding sources; all clone URLs already read `github.com/metadatastician/marid`.
