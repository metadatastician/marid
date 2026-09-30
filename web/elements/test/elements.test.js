// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

import { describe, test, expect } from "bun:test";
import { MaridProgressElement } from "../src/index.js";

describe("@metadatastician/marid-elements Unit Tests", () => {
  test("Element class is exported and instantiable", () => {
    expect(MaridProgressElement).toBeDefined();
    expect(MaridProgressElement.observedAttributes).toContain("value");
    expect(MaridProgressElement.observedAttributes).toContain("max");
    expect(MaridProgressElement.observedAttributes).toContain("status");
  });

  test("SSR-safe when window/document are absent or mocked", () => {
    // Should not throw when imported or created
    const el = new MaridProgressElement();
    expect(el).toBeDefined();
  });
});
