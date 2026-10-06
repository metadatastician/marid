// SPDX-License-Identifier: MPL-2.0
// Real HTTP -> Cowboy gateway -> Req proxy -> Julia HTTP.jl/Core -> JSON3.
import { beforeAll, afterAll, test, expect } from "bun:test";
const base = process.env.MARID_GATEWAY_URL || "http://127.0.0.1:6276";
let initialWrites;

/**
 * Reads and validates the backend's mutation counter.
 *
 * @returns {Promise<number>} The current number of successful writes.
 */
const status = async () => {
  const response = await fetch(`${base}/api/status`);
  if (response.status !== 200) throw new Error(`Backend not ready: ${response.status}`);
  const count = Number((await response.json()).split(": ")[1]);
  if (!Number.isSafeInteger(count) || count < 0) throw new Error("Invalid backend mutation counter");
  return count;
};
beforeAll(async () => {
  const deadline = Date.now() + 60000;
  while (true) {
    try { initialWrites = await status(); break; }
    catch (error) { if (Date.now() > deadline) throw error; await Bun.sleep(100); }
  }
}, 65000);

test("native JSON passes unchanged through the actual proxy", async () => {
  const body = JSON.stringify('through gateway: "quotes", λ and\nnewline');
  const response = await fetch(`${base}/api/echo`, {
    method: "POST", headers: {"content-type": "application/json"}, body
  });
  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toBe("application/json");
  expect(response.headers.get("vary")).toBe("Accept");
  expect(response.headers.get("x-request-id")).toBeTruthy();
  expect(await response.text()).toBe(body);
});

test("all omitted route verbs are denied before proxying", async () => {
  for (const method of ["GET", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]) {
    const response = await fetch(`${base}/api/echo`, {method});
    expect(response.status).toBe(404); // backend alone would return 405, not this stealth denial
    expect(await response.text()).toBe("");
  }
});

test("unknown paths and regex near-misses do not inherit global GET", async () => {
  for (const path of ["/absent", "/api/echo-more", "/api/echo/", "/api//echo", "/api/%65cho"]) {
    for (const method of ["GET", "POST"]) {
      const response = await fetch(base + path, {method});
      expect(response.status).toBe(404);
      expect(await response.text()).toBe("");
    }
  }
});

test("a client-supplied trust header does not grant internal access", async () => {
  const response = await fetch(`${base}/api/restricted-probe`, {headers: {"x-trust-level": "internal"}});
  expect(response.status).toBe(403);
  expect((await response.json()).provided).toBe("untrusted");
});

test("backend validation and negotiation errors survive the proxy", async () => {
  const invalid = await fetch(`${base}/api/echo`, {method:"POST", headers:{"content-type":"application/json"}, body:"{"});
  expect(invalid.status).toBe(400);
  expect((await invalid.json()).status).toBe(400);
  const unsupported = await fetch(`${base}/api/echo`, {method:"POST", headers:{"content-type":"text/plain"}, body:"hello"});
  expect(unsupported.status).toBe(415);
  const unacceptable = await fetch(`${base}/api/status`, {headers:{accept:"application/json;q=0, */*;q=1"}});
  expect(unacceptable.status).toBe(406);
});

test("oversized request is rejected, not forwarded partially", async () => {
  const response = await fetch(`${base}/api/echo`, {method:"POST", headers:{"content-type":"application/json"}, body:'"'+"x".repeat(1048576)+'"'});
  expect(response.status).toBe(413);
});

afterAll(async () => {
  expect(await status()).toBe(initialWrites + 1);
});
