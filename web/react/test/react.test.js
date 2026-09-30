// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

import { describe, test, expect } from "bun:test";
import { createMaridContext } from "../src/index.js";
import { MaridClient } from "@metadatastician/marid-client";

describe("@metadatastician/marid-react Unit Tests", () => {
  test("createMaridContext constructs bindings with React shim", () => {
    // Lightweight React mock for testing hook lifecycle
    const mockReact = {
      createContext: (initial) => ({ _currentValue: initial, Provider: "Provider" }),
      useContext: (ctx) => ctx._currentValue,
      useRef: (val) => ({ current: val }),
      useState: (initial) => [initial, () => {}],
      useEffect: (fn, deps) => {
        // Run cleanup test
        const cleanup = fn();
        if (typeof cleanup === "function") cleanup();
      },
      createElement: (type, props, ...children) => ({ type, props, children })
    };

    const bindings = createMaridContext(mockReact);
    expect(bindings.MaridProvider).toBeDefined();
    expect(bindings.useMaridClient).toBeDefined();
    expect(bindings.useMaridSubscription).toBeDefined();
  });

  test("Subscription cleans up upon unmount effect", () => {
    let cleanedUp = false;
    const mockClient = {
      subscribe: (topic, callbacks) => {
        return {
          unsubscribe: () => {
            cleanedUp = true;
          }
        };
      }
    };

    let cleanupFn = null;
    const mockReact = {
      createContext: (initial) => ({ _currentValue: mockClient }),
      useContext: (ctx) => mockClient,
      useRef: (val) => ({ current: val }),
      useEffect: (fn, deps) => {
        if (deps && deps.includes("taxa:all")) {
          cleanupFn = fn();
        }
      }
    };

    const { useMaridSubscription } = createMaridContext(mockReact);
    useMaridSubscription("taxa:all", { onEvent: () => {} });

    expect(cleanupFn).not.toBeNull();
    cleanupFn();
    expect(cleanedUp).toBe(true);
  });
});
