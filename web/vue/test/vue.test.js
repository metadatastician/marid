// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

import { describe, test, expect } from "bun:test";
import { createMaridPlugin, createVueComposables } from "../src/index.js";

describe("@metadatastician/marid-vue Unit Tests", () => {
  test("createMaridPlugin installs client into app", () => {
    const mockApp = {
      provideCalls: [],
      provide(key, val) {
        this.provideCalls.push({ key, val });
      }
    };

    const dummyClient = { id: "test-client" };
    const plugin = createMaridPlugin(dummyClient);
    plugin.install(mockApp);

    expect(mockApp.provideCalls.length).toBe(1);
    expect(mockApp.provideCalls[0].val).toBe(dummyClient);
  });

  test("Subscription cleans up onUnmounted hook", () => {
    let unmountedHook = null;
    let unsubscribed = false;

    const mockVue = {
      inject: () => ({
        subscribe: (topic, callbacks) => ({
          unsubscribe: () => { unsubscribed = true; },
          cancel: () => { unsubscribed = true; }
        })
      }),
      ref: (init) => ({ value: init }),
      onUnmounted: (fn) => { unmountedHook = fn; }
    };

    const { useMaridSubscription } = createVueComposables(mockVue);
    useMaridSubscription("taxa:updates", {});

    expect(unmountedHook).not.toBeNull();
    unmountedHook();
    expect(unsubscribed).toBe(true);
  });
});
