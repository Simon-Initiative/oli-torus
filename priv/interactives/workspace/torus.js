/* Torus Interactive SDK v1. Copy unchanged alongside index.html. */
(function (global) {
  'use strict';
  const channel = 'torus.interactive.v1';
  let sequence = 0;
  let parentOrigin;
  const pending = new Map();
  let scheduleMeasure = () => {};

  function observeSize() {
    const doc = global.document;
    if (!doc?.body || global.parent === global) return;
    // Document roots use natural flow inside an auto-height embed. Viewport-sized roots
    // plus padding/margins otherwise grow on every parent resize (100vh -> larger 100vh).
    for (const root of [doc.documentElement, doc.body]) {
      root.style.setProperty('height', 'auto', 'important');
      root.style.setProperty('min-height', '0', 'important');
    }
    let scheduled = false, lastHeight = 0;
    const measure = () => {
      scheduled = false;
      const body = doc.body;
      const rect = body.getBoundingClientRect();
      const bottomMargin = parseFloat(global.getComputedStyle(body).marginBottom) || 0;
      const viewport = global.innerHeight;
      const height = Math.ceil(Math.max(1, rect.bottom + global.scrollY + bottomMargin,
        body.scrollHeight > viewport + 1 ? body.scrollHeight : 0,
        doc.documentElement.getBoundingClientRect().bottom + global.scrollY));
      if (height !== lastHeight) {
        lastHeight = height;
        global.parent.postMessage({ channel, type: 'resize', height }, parentOrigin || '*');
      }
    };
    scheduleMeasure = () => {
      if (!scheduled) { scheduled = true; global.requestAnimationFrame(measure); }
    };
    if (global.ResizeObserver) new global.ResizeObserver(scheduleMeasure).observe(doc.body);
    if (global.MutationObserver) new global.MutationObserver(scheduleMeasure).observe(doc.body,
      { subtree: true, childList: true, attributes: true, characterData: true });
    global.addEventListener('resize', scheduleMeasure);
    global.addEventListener('load', scheduleMeasure, true);
    doc.fonts?.ready.then(scheduleMeasure);
    scheduleMeasure();
  }
  if (global.document?.readyState === 'loading') {
    global.document.addEventListener('DOMContentLoaded', observeSize, { once: true });
  } else observeSize();

  global.addEventListener('message', (event) => {
    const message = event.data;
    if (event.source !== global.parent || !message || message.channel !== channel ||
        (parentOrigin && event.origin !== parentOrigin)) return;
    if (message.type === 'measure') { scheduleMeasure(); return; }
    const request = pending.get(message.id);
    if (!request) return;
    pending.delete(message.id);
    global.clearTimeout(request.timer);
    if (request.retry) global.clearInterval(request.retry);
    parentOrigin = event.origin;
    if (message.error) {
      const error = new Error(message.error.code);
      error.code = message.error.code;
      request.reject(error);
    } else request.resolve(message.result);
  });

  function request(method, params) {
    return new Promise((resolve, reject) => {
      if (global.parent === global) {
        const error = new Error('unavailable'); error.code = 'unavailable'; reject(error); return;
      }
      const id = `${Date.now()}-${++sequence}`;
      let retry;
      const timer = global.setTimeout(() => {
        if (retry) global.clearInterval(retry);
        pending.delete(id);
        const error = new Error('timeout'); error.code = 'timeout'; reject(error);
      }, 30000);
      const send = () => global.parent.postMessage({ channel, id, method, params }, parentOrigin || '*');
      pending.set(id, { resolve, reject, timer });
      // Only the read-only connection handshake retries; writes/finalizations remain one-shot.
      if (method === 'context') {
        retry = global.setInterval(send, 250);
        pending.get(id).retry = retry;
      }
      send();
    });
  }

  global.TorusInteractive = Object.freeze({
    async connect() {
      let context = await request('context');
      async function mutate(method, params) {
        if (context.readOnly) {
          const error = new Error('read_only'); error.code = 'read_only'; throw error;
        }
        const result = await request(method, params);
        if (method === 'parts.finalize' || method === 'activity.finalize') context = result;
        return result;
      }
      const state = (scope) => Object.freeze({
        get: (key) => request(`${scope}.get`, { key }),
        set: (key, value) => mutate(`${scope}.set`, { key, value }),
      });
      return Object.freeze({
        get context() { return context; },
        attempt: state('attempt'),
        section: state('section'),
        parts: Object.freeze({ finalize: ({ partId, response, correct }) =>
          mutate('parts.finalize', { partId, response, correct }) }),
        activity: Object.freeze({ finalize: () => context.status === 'evaluated'
          ? Promise.resolve(context) : mutate('activity.finalize') }),
      });
    },
  });
})(window);
