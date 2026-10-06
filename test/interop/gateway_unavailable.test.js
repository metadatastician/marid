// SPDX-License-Identifier: MPL-2.0
// Run only AFTER the test backend has stopped, while the gateway is still up.
import { test, expect } from "bun:test";
const base = process.env.MARID_GATEWAY_URL || "http://127.0.0.1:6276";
test("backend outage is 502 while policy denial remains local", async () => {
  const allowed = await fetch(`${base}/api/status`);
  expect(allowed.status).toBe(502);
  expect((await allowed.json()).message).toBe("Backend service unavailable");
  const forbidden = await fetch(`${base}/api/echo`, {method:"DELETE"});
  expect(forbidden.status).toBe(404);
});
