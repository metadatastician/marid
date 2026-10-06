<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000005
parent: 6d617269-6400-7000-8000-000000000001
position: 40
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Web SDKs

The four browser packages under `web/` are the client-side face of Marid: one framework-independent client, two thin framework integrations and one Web Components demonstrator. They are published under the `@metadatastician/` scope, all at version `0.1.0`, and are managed as a single Bun workspace (`web/package.json`, name `marid-web`, `"private": true`, never published). See [[Architecture]] for the server side they talk to, [[Evidence]] for what has actually been proven, and [[Decisions]] for ADR-0005, which chose this shape.

## Runtime and language policy

| Topic | Rule | Source |
|---|---|---|
| Runtime and package manager | Bun only. Bun `1.4.2` is the pinned baseline. Node, npm, yarn, pnpm and Deno are ejected. | `mise.toml`, `.github/workflows/web-ci.yml`, `docs/adr/0005-affinescript-browser-client.adoc` |
| Language | TypeScript is forbidden for new application code by estate ruling 2026-08-25 (`LANGUAGE-POLICY.adoc` section 1.2). The intended language is AffineScript (JaffaScript face, `.affine` sources compiled to typed WebAssembly via `@hyperpolymath/affinescript`). | `docs/MARID-FRAMEWORK.adoc`, "Marid-local adaptations", TypeScript ejection paragraph; ADR-0005 |
| What is actually shipped | Plain ESM JavaScript. Every package has `"type": "module"` and `"main": "src/index.js"`. Two `.affine` files exist (`web/client/src/client.affine`, `web/elements/src/progress.affine`) and contain record and linear-interface declarations only. No build script and no compiler dependency is declared in any `package.json`. | `web/*/package.json`, `web/*/src/` |
| AffineScript status | Still a feasibility blocker. The evidence ledger says "AffineScript compilation is still a feasibility blocker; no unverified compiler version is invented", the root README says the toolchain "is not yet proven and remains a Gate 0 blocker", and the 2026-09-19 recon records R11 (P1): "AffineScript build unproved". Nothing on this page claims that any `.affine` source compiles. | `docs/audits/evidence-ledger.adoc`, `README.adoc`, `docs/audits/recon-2026-09-19.adoc` |

The framework charter's own "Frontend story" names TypeScript code generators (`openapi-typescript`, orval, Kiota, Apollo/urql/Relay). The Marid-local adaptation overrides that: IR codegen targets AffineScript, and generated clients reach the React/Vue/Svelte ecosystems "through narrow plain-JavaScript interop facades". TypeScript survives only in the estate's transitional carve-out, "where AffineScript cannot reach".

## The four packages

| Package | Directory | Purpose (from `package.json`) | Entry | Depends on |
|---|---|---|---|---|
| `@metadatastician/marid-client` | `web/client/` | Framework-independent browser client for Marid | `src/index.js` | nothing |
| `@metadatastician/marid-elements` | `web/elements/` | Portable Web Components demonstrator | `src/index.js` | nothing |
| `@metadatastician/marid-react` | `web/react/` | Thin React lifecycle integration for the client | `src/index.js` | `@metadatastician/marid-client` (`workspace:*`) |
| `@metadatastician/marid-vue` | `web/vue/` | Thin Vue 3 lifecycle integration for the client | `src/index.js` | `@metadatastician/marid-client` (`workspace:*`) |

All four are licensed MPL-2.0 (the READMEs are CC-BY-SA-4.0). `web/bun.lock` records only the four workspace members and the two `workspace:*` edges; there are no third-party dependencies.

### `@metadatastician/marid-client`

`web/client/src/index.js` implements:

- **RFC 9457 problem-details mapping.** `MaridError.fromProblemDetails(pd)` reads `status`, `detail` and `title` from a problem-details body and returns a typed subclass: `NotFoundError` (404), `ValidationError` (400), `ConflictError` (409), `UnauthorizedError` (401 or 403), `TimeoutError` (504 or 408), otherwise `MaridError` with the original status. Each error carries `status` and `details`.
- **`fetchJson(path, options)`.** Builds the URL from `baseUrl`, sends `Accept: application/json, application/problem+json`, JSON-encodes object bodies, honours a caller `AbortSignal`, and applies a timeout (`defaultTimeoutMs`, 30000 by default) through its own `AbortController`. A non-OK response is parsed as problem details and thrown through the mapping above; a 204 returns `null`. The fetch implementation is injectable (`config.fetch`), which is how the tests run without a browser.
- **SSE subscription with reconnection.** `subscribe(topic, callbacks, options)` requests `GET {baseUrl}/events?topic=...&last_event_id=N` with `Accept: text/event-stream`, parses `event:`, `id:` and `data:` lines from the stream, and tracks the highest `sequence` seen per topic in `lastSequenceByTopic` so a reconnect resumes from it. An event whose `type` is `marid.sync.resync_required` (or whose SSE event name is `resync_required`) is routed to `onResyncRequired`; everything else goes to `onEvent`. On a thrown error the client reconnects after `options.reconnectIntervalMs` (default 1000 ms) unless the subscription was cancelled. The returned handle exposes `topic`, `isClosed`, `unsubscribe()` and `cancel()`.
- **Linear trailing-slash normalisation.** `stripTrailingSlashes` replaces a `.replace(/\/+$/, "")` that CodeQL flagged as polynomial (`js/polynomial-redos`).

One limitation is recorded in the recon and visible in the source: the reconnect path is only reached from the `catch` block. When the server closes the stream cleanly (`done` is true), the read loop exits without reconnecting (recon R11: "SSE clean EOF does not reconnect").

The client README states the compatibility requirements the package is meant to meet: no `window` or `document` access merely from importing the SDK; request-scoped credentials and caches for SSR; reconnection that detects missed updates and resynchronises; older browser bundles that stay compatible during rolling server deployments. `web/README.adoc` adds that existing GraphQL and generated API clients must also keep working directly; nothing forces every consumer through this SDK.

### `@metadatastician/marid-elements`

`web/elements/src/index.js` defines `MaridProgressElement`, registered as `<marid-progress>` when `customElements` exists. It observes the attributes `value`, `max`, `status` and `indeterminate`, exposes them as properties, renders a label row and a track/bar into an open shadow root, and dispatches two composed, bubbling events: `marid-progress-change` (with `value`, `max`, `percentage`, `status`) on every render and `marid-progress-complete` when the percentage reaches 100 in determinate mode. Styling hooks are the CSS custom properties `--marid-progress-track`, `--marid-progress-bar` and `--marid-progress-text`.

The shadow DOM is built with `createElement` and `append`, not `innerHTML`; the evidence ledger records that change ("Fixed-template innerHTML parsing replaced with DOM construction; it was not shown to accept attacker HTML"). When `HTMLElement` is undefined the class extends an in-file `ElementFallback` that stores attributes in a `Map`, which is what lets the module load and instantiate under Bun without a DOM.

The elements README describes the package as a small demonstrator built on Custom Elements, properties, DOM events and explicit styling hooks, "not a new comprehensive widget library".

### `@metadatastician/marid-react`

`web/react/src/index.js` exports `createMaridContext(React)`. React is passed in rather than imported, so the package declares no React dependency. The factory returns `MaridContext`, `MaridProvider` (a context provider taking a `client`), `useMaridClient` (throws if used outside the provider), `useMaridSubscription(topic, callbacks)` (subscribes in an effect, keeps the latest callbacks in a ref, and calls `sub.unsubscribe()` in the effect cleanup, so unmounting cleans up the subscription) and `useMaridQuery(path, options)` (runs `fetchJson` with an `AbortController`, returns `{ data, loading, error }`, ignores `AbortError`, and aborts on cleanup).

### `@metadatastician/marid-vue`

`web/vue/src/index.js` exports `createMaridPlugin(client)`, whose `install(app)` calls `app.provide(MARID_CLIENT_KEY, client)`, and `createVueComposables(Vue)`, which takes `inject`, `ref` and `onUnmounted` from the passed-in Vue and returns `useMaridClient`, `useMaridSubscription(topic, callbacks)` (returns `{ isConnected, cancel }` and unsubscribes in `onUnmounted`) and `useMaridQuery(path, options)` (returns `{ data, loading, error }` refs and aborts the request in `onUnmounted`). As with React, Vue is not a declared dependency.

## Running the tests

Every package has `"scripts": { "test": "bun test" }`, and the workspace root runs them all:

```bash
cd web
bun install --frozen-lockfile
bun test
```

`web/test` files and what they cover:

| File | Tests | What is exercised |
|---|---|---|
| `web/client/test/client.test.js` | 7 | Successful JSON parse; `NotFoundError` on 404; `ValidationError` on 400; SSE event delivery and `cancel()`; `onResyncRequired` on a resync event; trailing-slash normalisation; the linear-time guarantee of `stripTrailingSlashes` (hostile 100000-slash input under 250 ms) |
| `web/elements/test/elements.test.js` | 2 | Class is exported with the expected `observedAttributes`; instantiation does not throw without `window` or `document` |
| `web/react/test/react.test.js` | 2 | `createMaridContext` builds the bindings against a React shim; the subscription effect cleanup calls `unsubscribe()` |
| `web/vue/test/vue.test.js` | 2 | `createMaridPlugin` provides the client to a mock app; the `onUnmounted` hook unsubscribes |

All of these inject a mock `fetch`, a mock React or a mock Vue. None starts a browser.

The CI workflow for this directory is `Web CI` (`.github/workflows/web-ci.yml`): it runs on pushes to `main` touching `web/**` or the workflow itself, on every pull request and on manual dispatch; installs Bun `1.4.2` with `oven-sh/setup-bun@v2.2.0`; runs `bun install --frozen-lockfile` and `bun test` in `web/`; and then refuses to pass unless the number of files Bun reports equals the number of `*.test.js` files found and at least one test ran, because `bun test` exits 0 having run nothing. The workflow comment records that the workspace install is what makes `@metadatastician/marid-client` resolve for the React and Vue packages (D226), so a green run is also proof that the packages resolve by name rather than by path. See [[CI-and-Operations]].

## What the evidence says

The acceptance evidence ledger (`docs/audits/evidence-ledger.adoc`, updated 2026-09-19) is authoritative, and its line on this surface is exact:

> Existing Bun shim/unit tests pass; this is not real-browser acceptance.

The same recon (`docs/audits/recon-2026-09-19.adoc`) describes the four packages as "working JavaScript prototype facades and unit tests; AffineScript records exist but package entrypoint is JS and no AffineScript build script/compiler dependency is declared there. React/Vue tests use shims; browser compatibility is not proven by those tests", and files R11 at priority P1 with the remedy "Real compiler/build, real browsers, lifecycle/SSR/cancellation/resync matrix". The brief section 8 ledger row for unit tests reads "Unit coverage only".

So the honest state is: implemented as plain JavaScript, unit-tested under Bun, wired into CI, and neither compiled from AffineScript nor accepted in a real browser. See [[Roadmap]] for where that work sits.

## Known stale statements in the sources

Flagged here rather than silently corrected; the source files still say these things.

- **(A) Gate 0 wording.** `web/README.adoc` says "Status: Gate 0 skeleton" and that packages "are implemented at Gate 4"; all four package READMEs are titled "(planned)" and say "Status: Gate 0 skeleton. Implemented at Gate 4." The `src/index.js` entry points, tests and `Web CI` workflow exist, so "skeleton" and "planned" no longer describe the directory. The accurate status is the evidence ledger's: prototype facades with Bun unit tests, not browser-accepted.
- **Language claim versus artefact.** `web/README.adoc` and the four package READMEs say the client is "written in AffineScript" and "compiled to typed WebAssembly". The shipped entry points are plain ESM JavaScript and no compiler is declared; the `.affine` files hold declarations only.
- **Package names in ADR-0005.** `docs/adr/0005-affinescript-browser-client.adoc` names the packages `@marid/client`, `@marid/react`, `@marid/vue` and `@marid/elements`. The `package.json` names are `@metadatastician/marid-client`, `-react`, `-vue` and `-elements`.
- **`.a2ml` citations.** ADR-0005 cites `ANCHOR.a2ml` twice as the source of the TypeScript ban. Zero `.a2ml` files exist in the repository; the machine-readable descriptors are now `.deed` files (`0-AI-MANIFEST.deed`, `.machine_readable/descriptiles/marid_chora.deed`).
- Patterns (B) `packages/ArangoDB` and (C) `github.com/hyperpolymath/marid` were not found in the sources read for this page (`web/`, ADR-0005, the two `docs/MARID-FRAMEWORK.adoc` sections). The Julia storage package is `packages/MaridArango`; see [[Packages]].
