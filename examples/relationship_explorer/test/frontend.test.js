// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

import { describe, test, expect } from "bun:test";
import { MaridClient } from "../../../web/client/src/index.js";
import { MaridProgressElement } from "../../../web/elements/src/index.js";

describe("Relationship Explorer Frontend Integration", () => {
  test("Shared Web Component initializes correctly", () => {
    const el = new MaridProgressElement();
    expect(el).toBeDefined();
    el.value = 50;
    expect(el.value).toBe(50);
    el.status = "Analyzing clades";
    expect(el.status).toBe("Analyzing clades");
  });

  test("Client fetches mock analysis results without error", async () => {
    const mockFetch = async (url, opts) => {
      return {
        ok: true,
        status: 200,
        json: async () => ({
          type: "result",
          newick: "(Homo_sapiens,Pan_troglodytes);",
          parsimony_score: 3.0,
          taxa: ["Homo sapiens", "Pan troglodytes"]
        })
      };
    };

    const client = new MaridClient({ baseUrl: "http://127.0.0.1:6274", fetch: mockFetch });
    const res = await client.fetchJson("/api/v1/analysis", { method: "POST" });
    expect(res.type).toBe("result");
    expect(res.parsimony_score).toBe(3.0);
    expect(res.newick).toContain("Homo_sapiens");
  });
});
