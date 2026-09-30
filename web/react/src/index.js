// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

/**
 * @metadatastician/marid-react
 * Thin React integration over @metadatastician/marid-client providing ergonomic hooks
 * and guaranteed unmount subscription cleanup.
 */

import { MaridClient } from "@metadatastician/marid-client";

export function createMaridContext(React) {
  const MaridContext = React.createContext(null);

  function MaridProvider({ client, children }) {
    return React.createElement(MaridContext.Provider, { value: client }, children);
  }

  function useMaridClient() {
    const client = React.useContext(MaridContext);
    if (!client) {
      throw new Error("useMaridClient must be used within a MaridProvider");
    }
    return client;
  }

  function useMaridSubscription(topic, callbacks = {}) {
    const client = useMaridClient();
    const savedCallbacks = React.useRef(callbacks);

    React.useEffect(() => {
      savedCallbacks.current = callbacks;
    });

    React.useEffect(() => {
      if (!topic) return;

      const sub = client.subscribe(topic, {
        onEvent: (evt) => savedCallbacks.current.onEvent?.(evt),
        onError: (err) => savedCallbacks.current.onError?.(err),
        onResyncRequired: () => savedCallbacks.current.onResyncRequired?.()
      });

      return () => {
        sub.unsubscribe();
      };
    }, [client, topic]);
  }

  function useMaridQuery(path, options = {}) {
    const client = useMaridClient();
    const [data, setData] = React.useState(null);
    const [loading, setLoading] = React.useState(true);
    const [error, setError] = React.useState(null);

    React.useEffect(() => {
      let isCurrent = true;
      const controller = new AbortController();
      setLoading(true);
      setError(null);

      client.fetchJson(path, { ...options, signal: controller.signal })
        .then((result) => {
          if (isCurrent) {
            setData(result);
            setLoading(false);
          }
        })
        .catch((err) => {
          if (isCurrent && err.name !== "AbortError") {
            setError(err);
            setLoading(false);
          }
        });

      return () => {
        isCurrent = false;
        controller.abort();
      };
    }, [client, path, JSON.stringify(options)]);

    return { data, loading, error };
  }

  return { MaridContext, MaridProvider, useMaridClient, useMaridSubscription, useMaridQuery };
}
