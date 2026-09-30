// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

/**
 * @marid/client
 * Framework-independent browser client for Marid APIs and event streaming.
 * SSR-safe, cancellation-aware, with RFC 9457 problem details error handling
 * and SSE reconnection with sequence tracking.
 */

export class MaridError extends Error {
  constructor(message, status = 500, details = {}) {
    super(message);
    this.name = "MaridError";
    this.status = status;
    this.details = details;
  }

  static fromProblemDetails(pd) {
    const status = pd.status || 500;
    const msg = pd.detail || pd.title || "Marid API Error";
    if (status === 404) return new NotFoundError(msg, pd);
    if (status === 400) return new ValidationError(msg, pd);
    if (status === 409) return new ConflictError(msg, pd);
    if (status === 401 || status === 403) return new UnauthorizedError(msg, pd);
    if (status === 504 || status === 408) return new TimeoutError(msg, pd);
    return new MaridError(msg, status, pd);
  }
}

export class NotFoundError extends MaridError {
  constructor(message, details = {}) {
    super(message, 404, details);
    this.name = "NotFoundError";
  }
}

export class ValidationError extends MaridError {
  constructor(message, details = {}) {
    super(message, 400, details);
    this.name = "ValidationError";
  }
}

export class ConflictError extends MaridError {
  constructor(message, details = {}) {
    super(message, 409, details);
    this.name = "ConflictError";
  }
}

export class UnauthorizedError extends MaridError {
  constructor(message, details = {}) {
    super(message, 401, details);
    this.name = "UnauthorizedError";
  }
}

export class TimeoutError extends MaridError {
  constructor(message, details = {}) {
    super(message, 504, details);
    this.name = "TimeoutError";
  }
}

// Strip trailing "/" in linear time. `.replace(/\/+$/, "")` is polynomial
// on a run of slashes that is not at the end (CodeQL js/polynomial-redos,
// security-severity 7.5).
function stripTrailingSlashes(s) {
  let end = s.length;
  while (end > 0 && s.charCodeAt(end - 1) === 47) end--;
  return s.slice(0, end);
}

export class MaridClient {
  constructor(config = {}) {
    this.baseUrl = stripTrailingSlashes(config.baseUrl || "");
    this.fetchImpl = config.fetch || (typeof fetch !== "undefined" ? fetch.bind(globalThis) : null);
    this.headers = config.headers || {};
    this.defaultTimeoutMs = config.defaultTimeoutMs || 30000;
    this.lastSequenceByTopic = new Map();
  }

  async fetchJson(path, options = {}) {
    if (!this.fetchImpl) {
      throw new Error("No fetch implementation available in current environment");
    }

    const url = path.startsWith("http") ? path : `${this.baseUrl}${path.startsWith("/") ? "" : "/"}${path}`;
    const timeoutMs = options.timeoutMs || this.defaultTimeoutMs;
    const controller = new AbortController();
    let timeoutId = null;

    if (options.signal) {
      options.signal.addEventListener("abort", () => controller.abort());
    }

    if (timeoutMs > 0) {
      timeoutId = setTimeout(() => {
        controller.abort(new TimeoutError(`Request timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    }

    try {
      const headers = {
        "Accept": "application/json, application/problem+json",
        ...this.headers,
        ...(options.headers || {})
      };

      if (options.body && typeof options.body === "object" && !(options.body instanceof FormData)) {
        headers["Content-Type"] = "application/json";
      }

      const res = await this.fetchImpl(url, {
        method: options.method || "GET",
        headers,
        body: options.body ? (typeof options.body === "string" ? options.body : JSON.stringify(options.body)) : undefined,
        signal: controller.signal
      });

      if (!res.ok) {
        let errBody = null;
        try {
          errBody = await res.json();
        } catch (_) {
          errBody = { title: res.statusText, status: res.status, detail: await res.text().catch(() => "") };
        }
        throw MaridError.fromProblemDetails(errBody);
      }

      if (res.status === 204) return null;
      return await res.json();
    } finally {
      if (timeoutId) clearTimeout(timeoutId);
    }
  }

  subscribe(topic, callbacks = {}, options = {}) {
    let closed = false;
    let abortController = new AbortController();
    const { onEvent, onError, onResyncRequired } = callbacks;
    let lastSeq = this.lastSequenceByTopic.get(topic) || 0;

    const connect = async () => {
      if (closed) return;
      abortController = new AbortController();

      const url = `${this.baseUrl}/events?topic=${encodeURIComponent(topic)}&last_event_id=${lastSeq}`;

      try {
        const response = await this.fetchImpl(url, {
          headers: {
            "Accept": "text/event-stream",
            "Cache-Control": "no-cache",
            ...this.headers
          },
          signal: abortController.signal
        });

        if (!response.ok) {
          throw new Error(`SSE HTTP error: ${response.status}`);
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";

        while (!closed) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n\n");
          buffer = lines.pop() || "";

          for (const block of lines) {
            const rawLines = block.split("\n");
            let eventType = "message";
            let eventId = null;
            let dataStr = "";

            for (const line of rawLines) {
              if (line.startsWith("event:")) {
                eventType = line.slice(6).trim();
              } else if (line.startsWith("id:")) {
                eventId = line.slice(3).trim();
              } else if (line.startsWith("data:")) {
                dataStr += (dataStr ? "\n" : "") + line.slice(5).trim();
              }
            }

            if (dataStr) {
              try {
                const parsed = JSON.parse(dataStr);
                if (parsed.sequence) {
                  lastSeq = parsed.sequence;
                  this.lastSequenceByTopic.set(topic, lastSeq);
                }

                if (parsed.type === "marid.sync.resync_required" || eventType === "resync_required") {
                  if (onResyncRequired) onResyncRequired(parsed);
                } else {
                  if (onEvent) onEvent(parsed);
                }
              } catch (e) {
                if (onError) onError(e);
              }
            }
          }
        }
      } catch (err) {
        if (!closed) {
          if (onError) onError(err);
          // Reconnect with backoff unless explicitly cancelled
          setTimeout(() => {
            if (!closed) connect();
          }, options.reconnectIntervalMs || 1000);
        }
      }
    };

    connect();

    return {
      topic,
      get isClosed() { return closed; },
      unsubscribe: () => {
        closed = true;
        abortController.abort();
      },
      cancel: () => {
        closed = true;
        abortController.abort();
      }
    };
  }
}
