<!-- berrywiki
id: 6d617269-6400-7000-8000-000000000010
parent: 6d617269-6400-7000-8000-000000000001
position: 90
kind: page
tags:
  - marid
  - julia
archived: false
-->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Deployment

What exists today is a **bounded, experimental unary HTTP/JSON slice** behind an HTTP capability governance sidecar, reproduced on a local socket. It is not a production acceptance. This page collects the deployment material in `docs/deployment/` and `examples/http_json/`, states exactly what has and has not been claimed, and gives the reproduction commands. The authoritative record of what has been proven is `docs/audits/evidence-ledger.adoc` (see [[Evidence]]); the program gates are on [[Roadmap]].

Sources: `docs/deployment/docker-compose.adoc`, `docs/deployment/compose.yaml`, `docs/deployment/PRODUCTION-GUIDE.adoc`, `examples/http_json/README.adoc`, and the "Local governed HTTP/JSON checkpoint" section of `README.adoc`.

## What is and is not claimed

| Claim | Status | Where the source says so |
|---|---|---|
| A real IR-driven Julia HTTP/JSON service on a local socket | Reproduced locally | `docs/deployment/docker-compose.adoc`, "Reproduce the local socket acceptance" |
| Policy generated from the same IR descriptor that binds the routes | Reproduced locally | `examples/http_json/README.adoc` |
| Container deployment | **Not claimed.** The Compose file is configuration only; `docker compose config` was validated, the engine was not run, and no Docker/Podman daemon was available in the evaluation | `README.adoc` ("no container deployment is claimed"); `docs/deployment/docker-compose.adoc`, "Compose wiring (configuration validated; engine not run)" |
| Strict (deny-by-default) gateway mode | Requires the paired gateway change: a gateway at or after `hyperpolymath/http-capability-gateway#112`, commit `c67c743c6c9f54c0482c1dd8d8dc151ff919551d`. Unmodified older upstream rejects empty `global_verbs` | `README.adoc` ("Strict mode requires the separately delivered gateway patch, not unmodified upstream") |
| TLS or mTLS | **Not accepted.** "Nothing here is a deployment, TLS, persistence or load acceptance claim"; "mTLS has not been accepted in this exercise" | `docs/deployment/docker-compose.adoc` |
| Persistence or a persistent reference application | **Not claimed.** The example's echo counter is deliberately in-memory; the example claims no persistence, authentication, schema validation, SSE, WS or HTTP/2 | `examples/http_json/README.adoc`; `README.adoc` ("there is no real persistence or application authentication in this demonstration") |
| Audit persistence | Not accepted. Audit traffic in the local run goes to an isolated unused loopback port | `docs/deployment/docker-compose.adoc` |
| Full gateway test suite green | **No.** 12 properties / 263 tests, 15 failures at seed 1 on the pinned baseline | `docs/deployment/docker-compose.adoc`, "Remaining blockers" |

No charter requirement is waived by the successful local unary slice.

## Trust boundary

```
client -> evaluated TLS ingress -> gateway:4000 -> marid:8080
                                    YAML          private backend network
```

Only the gateway publishes a host port. Ingress must block gateway-owned management URLs. The application still owns authentication and object-level authorization; a verb/exposure/capability spec does not implement those. Capability strings in the policy are metadata, not signed tokens.

## The local governed HTTP/JSON checkpoint

The `examples/http_json/` example binds its listener and its emitted capability policy to one `MaridIR.ServiceDescriptor`. It uses HTTP.jl for HTTP/1.1 and JSON3 for JSON. The MaridCore integration is an optional package extension: loading Core alone does not load Codec or Transport.

Routes in the example:

| Route | Method | Behaviour |
|---|---|---|
| `/api/echo` | POST | Accepts and returns a JSON string |
| `/api/status` | GET | Reports the in-memory mutation count |
| `/healthz` | GET | Explicit IR health route |
| `/api/restricted-probe` | GET | Synthetic internal-exposure route used to test forged trust-header rejection; returns no private data |

Run it:

```bash
julia --startup-file=no scripts/bootstrap.jl examples/http_json
julia --startup-file=no --project=examples/http_json examples/http_json/test/runtests.jl
MARID_HOST=127.0.0.1 MARID_PORT=8080 julia --startup-file=no --project=examples/http_json examples/http_json/server.jl
curl -i -H 'Content-Type: application/json' --data '"hello"' http://127.0.0.1:8080/api/echo
```

The test suite uses real sockets, the HTTP.jl client, a raw chunked socket and curl. It verifies routing, JSON escaping, `q=0` rejection, error paths, bounded request body, error redaction, cooperative deadline, explicit draining and listener shutdown.

Limits the example states about itself:

- Encoded or non-canonical paths are rejected rather than normalised behind governance.
- No automatic HEAD or OPTIONS binding is created.
- Handlers must return one closed output stream, cooperatively meet deadlines, and validate and authorise their own inputs.
- Arbitrary Julia computation cannot be forcibly cancelled; uncooperative CPU work, infinite streams and general stream cancellation remain a release blocker.
- The response size limit is checked after JSON serialisation; it is not a total heap quota.
- `close(server)` invokes HTTP.jl shutdown and clears readiness; draining is requested with `app.is_draining = true`. No orchestrator or SIGTERM grace-budget acceptance is implied.
- Inside a container the listener must bind `0.0.0.0` explicitly, and the backend must not be published around the governance gateway.

## Generating a capability policy from the IR

A descriptor file is executable trusted Julia; never run an untrusted one. The final expression must return `MaridIR.ServiceDescriptor`. Only explicit HTTP bindings are emitted; protocol adapters are not invented by policy generation.

Legacy profile (any gateway accepts it):

```bash
scripts/marid generate capability-spec examples/http_json/service.jl \
  --global-verbs GET --out docs/deployment/policy.yaml
```

Strict profile (needs a gateway at or after `#112`):

```bash
scripts/marid generate capability-spec fixtures/capability/service.jl \
  --deny-by-default --out fixtures/capability/policy-strict.yaml
```

Equivalent Julia API:

```julia
using MaridIR
svc = include("examples/http_json/service.jl")
yaml = emit_capability_spec(svc; gateway_profile=:strict, global_verbs=String[])
```

`--out` is opened only after the emitter succeeds, so a failed generation cannot truncate a live policy. Strict native DSL v1 has `global_verbs: []`; unknown application paths deny; a matched path owns its verb allowlist and omitted verbs cannot inherit globals; exact paths take precedence; multiple distinct matching regex patterns deny. The legacy `--global-verbs GET` profile is explicitly not deny-by-default, and on old upstream it is a public fallback even on matched paths with missing verbs. The CLI warns and never silently opts a caller into either model.

`build/container/compose.yaml` mounts the legacy golden `fixtures/capability/policy.yaml` because `:latest` is a mutable tag that cannot be verified to contain `#112`.

Mapping rules worth knowing before you annotate a service:

- Allowed methods are GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS. HEAD and OPTIONS are not inferred.
- Identical paths merge verbs and must carry identical governance metadata.
- `:id` is one segment; terminal `/*` is one or more segments; patterns are anchored with `\A` and `\z`.
- Canonical paths only: no repeated or trailing slash, no percent encoding, query, fragment or `{id}`.
- Overlapping IR routes are rejected at emission.
- `gateway.exposure` is `public`, `authenticated` or `internal` (default `public`); `gateway.capability` is a non-empty label; unknown `gateway.*` keys reject. Application `auth` annotations are not converted into authenticated identities.
- Gateway-owned GET `/health`, `/ready`, `/metrics` and `/api/v1/minikaran` bypass application policy.

## Reproducing the local socket acceptance

Toolchain: Julia 1.10.10, Bun 1.4.2, Elixir 1.19.4 and OTP 27 with development headers (Julia and Bun pins are in `mise.toml`; see [[Onboarding]]). Check out the gateway at `c67c743c6c9f54c0482c1dd8d8dc151ff919551d` with no patch on top, install Hex and Rebar, and run `mix deps.get` in that checkout. To confirm the pin carries the correction, run `grep 'must be a list (empty denies unmatched routes)' lib/http_capability_gateway/policy_validator.ex` in the gateway checkout; the CI job asserts the same.

```bash
julia --startup-file=no scripts/bootstrap.jl examples/http_json
julia --startup-file=no --project=examples/http_json examples/http_json/test/runtests.jl
bash test/interop/capability_cli.sh
elixir test/interop/capability_gateway.exs ../http-capability-gateway
bash test/interop/run_http_gateway.sh ../http-capability-gateway
```

The one-shot runner starts the real gateway application and the Julia service, generates policy from the same IR, exercises real HTTP, stops the backend, checks 502 and local denials, then cleans up. Ports 18080 and 18088 must be free. The launcher sets no trusted proxies and strips forged trust headers.

Recorded local result: seven Bun tests / 47 assertions across the two processes, plus 38 direct HTTP/JSON assertions and the native policy and compiler tests. The gateway's separate `ProxyWireTest` covers upstream query, header and body bytes, repeated Set-Cookie, no redirect following, no automatic retries, 503 preservation, and no forwarding of oversized requests. Counts and failures are in the evidence ledger ([[Evidence]]).

## Compose wiring (configuration only)

`docs/deployment/compose.yaml` is a configuration-only recipe. It requires independently tested images and the paired gateway change; there are deliberately no invented registry defaults.

| Service | Image variable | Ports | Networks | Notes |
|---|---|---|---|---|
| `http-capability-gateway` | `HTTP_CAPABILITY_GATEWAY_IMAGE` | `127.0.0.1:8088:4000` | `edge`, `backend` | Env `POLICY_PATH=/etc/marid/policy.yaml`, `BACKEND_URL=http://marid:8080`, `PORT=4000`, `TRUST_LEVEL_SOURCE=header`; read-only bind of `./policy.yaml` with `create_host_path: false`; healthcheck `wget http://127.0.0.1:4000/ready`; `cap_drop: [ALL]`, `no-new-privileges` |
| `marid` | `MARID_APP_IMAGE` | `expose: ["8080"]` only, no host port | `backend` | Entrypoint must serve HTTP on `0.0.0.0:8080`; `cap_drop: [ALL]`, `no-new-privileges` |

The `backend` network is `internal: true`. There are no database or application host ports, no host networking and no container socket.

```bash
: "${MARID_APP_IMAGE:?Set a tested application image digest}"
: "${HTTP_CAPABILITY_GATEWAY_IMAGE:?Set a reviewed patched gateway image digest}"
docker compose -f docs/deployment/compose.yaml config --quiet
# Only after image/runtime review and the release gates below:
# docker compose -f docs/deployment/compose.yaml up -d
```

Things the recipe does not do for you:

- Header mode is not authentication. The reviewed gateway image must set `strip_trust_header: true` and `trusted_proxies: []` (Elixir application settings, not Compose environment switches), or explicitly authorise only an independently evaluated ingress.
- `depends_on` is ordering, not readiness. Gateway `/ready` reports policy readiness, not backend or database health; a real application readiness probe must be provided separately.
- The read-only policy mount rejects an absent host file.
- The upstream Containerfile and config sequencing still require repair (production configuration reads `POLICY_PATH` at compile time; the initial dependency step loads config before its tree is copied). Consuming an image reference is not proof that its build works.

## The production guide

`docs/deployment/PRODUCTION-GUIDE.adoc` describes a target operating shape: Julia processes behind an edge proxy (Envoy for gRPC-Web translation, Caddy for automatic HTTPS and SSE flushing), the governance sidecar in front of the service, liveness at `GET /healthz`, readiness at `GET /readyz` returning 503 during startup and draining, SIGTERM draining with a 30-second flush budget for in-flight `Stream{T}` channels, and ArangoDB tuning (keep-alive pooling, cursor `batch_size`, `check_rev=true`). Treat it as a design target, not as acceptance: the guide's own closing section says that Marid's HTTP listener, full streaming proxy support and container end-to-end acceptance are not established by the framing helpers or deployment examples. The example actually implemented today exposes `/healthz`; it does not implement `/readyz` as described there.

## Remaining blockers

Do not deploy on these results alone. From `docs/deployment/docker-compose.adoc`:

- Full gateway suite red: 12 properties / 263 tests, 15 failures at seed 1, all reproducing on the same baseline with only two plugin compilation repairs. Baseline has 19 failures; fewer failures is not a green release gate.
- Resolver reports Cowboy, Cowlib and Mint security advisories; upgrade and re-evaluate first. Inactive WebhookHardener and XmlRpcShield plugins still warn about unsupported APIs.
- Proxy buffers responses without a general memory quota. Dynamic Connection header tokens, general streaming, cancellation, TLS and backend request-ID continuity need dedicated review. SSE, WS, gRPC and trailers are not supported claims.
- Real containers, management isolation, direct-port bypass, image provenance, absent or malformed policy readiness, certificate and ingress identity, resource benchmarks, graceful termination, restart and rollback all need a passing acceptance matrix.
- Safe reader retirement, reload races, dynamic table atom lifetime and production hot reload remain unaccepted. Deploy immutable app, gateway and policy revisions together.

Persistence and browser/protocol acceptance sit behind these gates. See [[CI-and-Operations]] for the workflow gates and [[Architecture]] for where the transport and governance seams sit.

## Known stale statements in the sources

- `docs/deployment/PRODUCTION-GUIDE.adoc` links to `docker-compose.adoc` as "complete container deployment manifests utilizing Podman pods and compose stacks". The linked document says the Compose configuration was validated but no engine was run and no daemon was available. The guide's architecture sections (edge proxy, ArangoDB cluster, `/readyz`, SIGTERM budget) describe a target, and its own final section says these are not established.
- `README.adoc` ("Where to go next") still labels `docs/marid-architecture.adoc`, `docs/marid-compatibility.adoc` and `docs/marid-roadmap.adoc` as "Gate 0 stub" and the agent-launch prompts as "the Gate 0 kickoff assignment", while the same README states that a prototype implementation exists (pattern A).
- `test/interop/README.adoc` still reads "Status: Gate 0 skeleton. Suites are built at Gates 3-4", while the directory holds the `capability_cli.sh`, `capability_gateway.exs`, `run_http_gateway.sh` and Bun interop tests that this page's reproduction commands run (pattern A).
- No `github.com/hyperpolymath/marid` URL, `packages/ArangoDB` path or `.a2ml` citation was found in the deployment sources listed at the top of this page. The gateway reference `hyperpolymath/http-capability-gateway#112` names a different repository and is not a stale Marid URL.
