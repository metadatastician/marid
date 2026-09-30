// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

/**
 * @metadatastician/marid-vue
 * Thin Vue 3 integration over @metadatastician/marid-client providing reactive composables
 * with automatic onUnmounted lifecycle cleanup.
 */

import { MaridClient } from "@metadatastician/marid-client";

const MARID_CLIENT_KEY = Symbol("MaridClient");

export function createMaridPlugin(client) {
  return {
    install(app) {
      app.provide(MARID_CLIENT_KEY, client);
    }
  };
}

export function createVueComposables(Vue) {
  const { inject, ref, onUnmounted } = Vue;

  function useMaridClient() {
    const client = inject(MARID_CLIENT_KEY);
    if (!client) {
      throw new Error("Marid client not provided. Use createMaridPlugin in app.use()");
    }
    return client;
  }

  function useMaridSubscription(topic, callbacks = {}) {
    const client = useMaridClient();
    const isConnected = ref(false);

    const sub = client.subscribe(topic, {
      onEvent: (evt) => {
        isConnected.value = true;
        callbacks.onEvent?.(evt);
      },
      onError: (err) => {
        callbacks.onError?.(err);
      },
      onResyncRequired: () => {
        callbacks.onResyncRequired?.();
      }
    });

    onUnmounted(() => {
      sub.unsubscribe();
      isConnected.value = false;
    });

    return { isConnected, cancel: () => sub.cancel() };
  }

  function useMaridQuery(path, options = {}) {
    const client = useMaridClient();
    const data = ref(null);
    const loading = ref(true);
    const error = ref(null);
    const controller = new AbortController();

    client.fetchJson(path, { ...options, signal: controller.signal })
      .then((res) => {
        data.value = res;
        loading.value = false;
      })
      .catch((err) => {
        if (err.name !== "AbortError") {
          error.value = err;
          loading.value = false;
        }
      });

    onUnmounted(() => {
      controller.abort();
    });

    return { data, loading, error };
  }

  return { useMaridClient, useMaridSubscription, useMaridQuery, MARID_CLIENT_KEY };
}
