// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

/**
 * @metadatastician/marid-elements
 * Portable Web Components demonstrator for reactive status and progress display.
 * Authored to standard Custom Elements v1 specs with explicit CSS styling hooks.
 */

const progressStyle = `  :host {
    display: inline-block;
    width: 100%;
    box-sizing: border-box;
    font-family: system-ui, -apple-system, sans-serif;
  }
  .track {
    width: 100%;
    height: 8px;
    background-color: var(--marid-progress-track, #e2e8f0);
    border-radius: 4px;
    overflow: hidden;
    position: relative;
  }
  .bar {
    height: 100%;
    background-color: var(--marid-progress-bar, #0284c7);
    transition: width 0.2s ease;
    width: 0%;
  }
  .indeterminate {
    animation: marid-indeterminate 1.5s infinite linear;
    width: 30% !important;
  }
  @keyframes marid-indeterminate {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(400%); }
  }
  .label-container {
    display: flex;
    justify-content: space-between;
    font-size: 0.85rem;
    margin-bottom: 4px;
    color: var(--marid-progress-text, #334155);
  }
`;

class ElementFallback {
  constructor() {
    this._attrs = new Map();
  }
  getAttribute(k) { return this._attrs.get(k) ?? null; }
  setAttribute(k, v) { this._attrs.set(k, String(v)); }
  removeAttribute(k) { this._attrs.delete(k); }
  hasAttribute(k) { return this._attrs.has(k); }
  dispatchEvent() {}
}

const BaseElement = typeof HTMLElement !== "undefined" ? HTMLElement : ElementFallback;

export class MaridProgressElement extends BaseElement {
  static get observedAttributes() {
    return ["value", "max", "status", "indeterminate"];
  }

  /** Creates a progress element and builds its shadow DOM when available. */
  constructor() {
    super();
    if (typeof this.attachShadow === "function") {
      this.attachShadow({ mode: "open" });
      const doc = this.ownerDocument;
      const style = doc.createElement("style");
      style.textContent = progressStyle;
      const labels = doc.createElement("div");
      labels.className = "label-container";
      for (const [className, text] of [["status", "Idle"], ["percentage", "0%"]]) {
        const span = doc.createElement("span");
        span.className = className;
        span.textContent = text;
        labels.append(span);
      }
      const track = doc.createElement("div");
      track.className = "track";
      const bar = doc.createElement("div");
      bar.className = "bar";
      track.append(bar);
      this.shadowRoot.append(style, labels, track);
      this._bar = this.shadowRoot.querySelector(".bar");
      this._status = this.shadowRoot.querySelector(".status");
      this._percentage = this.shadowRoot.querySelector(".percentage");
    }
  }

  connectedCallback() {
    this._render();
  }

  attributeChangedCallback() {
    this._render();
  }

  get value() {
    return parseFloat(this.getAttribute("value") || "0");
  }

  set value(val) {
    this.setAttribute("value", String(val));
  }

  get max() {
    return parseFloat(this.getAttribute("max") || "100");
  }

  set max(val) {
    this.setAttribute("max", String(val));
  }

  get status() {
    return this.getAttribute("status") || "Idle";
  }

  set status(val) {
    this.setAttribute("status", val);
  }

  get indeterminate() {
    return this.hasAttribute("indeterminate");
  }

  set indeterminate(val) {
    if (val) this.setAttribute("indeterminate", "");
    else this.removeAttribute("indeterminate");
  }

  _render() {
    if (!this.shadowRoot) return;
    const v = this.value;
    const m = this.max > 0 ? this.max : 100;
    const pct = Math.min(100, Math.max(0, Math.round((v / m) * 100)));

    if (this._status) this._status.textContent = this.status;

    if (this.indeterminate) {
      if (this._percentage) this._percentage.textContent = "...";
      if (this._bar) {
        this._bar.classList.add("indeterminate");
        this._bar.style.width = "30%";
      }
    } else {
      if (this._percentage) this._percentage.textContent = `${pct}%`;
      if (this._bar) {
        this._bar.classList.remove("indeterminate");
        this._bar.style.width = `${pct}%`;
      }
    }

    this.dispatchEvent(new CustomEvent("marid-progress-change", {
      detail: { value: v, max: m, percentage: pct, status: this.status },
      bubbles: true,
      composed: true
    }));

    if (pct >= 100 && !this.indeterminate) {
      this.dispatchEvent(new CustomEvent("marid-progress-complete", {
        detail: { status: this.status },
        bubbles: true,
        composed: true
      }));
    }
  }
}

if (typeof customElements !== "undefined" && !customElements.get("marid-progress")) {
  customElements.define("marid-progress", MaridProgressElement);
}
