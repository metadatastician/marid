# SPDX-License-Identifier: MPL-2.0
# Test launcher: full gateway application, not a mock router/compiler/proxy.
# Run from the gateway checkout: MIX_ENV=test mix run --no-start <this-file>
for {key, value} <- [
  policy_path: System.fetch_env!("POLICY_PATH"),
  backend_url: System.fetch_env!("BACKEND_URL"),
  port: String.to_integer(System.get_env("PORT", "6276")),
  strip_trust_header: true,
  trusted_proxies: [], # Loopback tests must not accidentally trust forged headers.
  rate_limits: %{untrusted: {10_000, 10_000}, authenticated: {10_000, 10_000}, internal: :unlimited}
] do
  Application.put_env(:http_capability_gateway, key, value)
end
{:ok, _} = Application.ensure_all_started(:http_capability_gateway)
IO.puts("MARID_GATEWAY_READY")
Process.sleep(:infinity)
