import { Frame, Page, Request } from '@playwright/test';

export type ExternalContentLog = { dump(): string };

/**
 * Records what the frames Torus embeds from other origins (the simulations) load, log and throw,
 * so that a simulation that never renders can be explained from the nightly report. The report is
 * public: nothing from the main frame or from Torus-origin frames is recorded, URLs keep only
 * their origin and path, and message text is cut at its first `?` or `#`.
 */
export function recordExternalContent(page: Page, torusBaseUrl: string): ExternalContentLog {
  const log: string[] = [];
  const pending = new Map<Request, { since: string; label: string }>();
  const watchedFrames = new WeakSet<Frame>();
  const startedAt = Date.now();
  const torusOrigin = new URL(torusBaseUrl).origin;
  const trackedTypes = new Set(['document', 'script', 'stylesheet', 'xhr', 'fetch']);

  const elapsed = () => `+${((Date.now() - startedAt) / 1000).toFixed(1)}s`;

  const externalUrl = (url: string) => {
    try {
      const parsed = new URL(url);
      const external = /^https?:$/.test(parsed.protocol) && parsed.origin !== torusOrigin;
      return external ? `${parsed.origin}${parsed.pathname}` : null;
    } catch {
      return null;
    }
  };

  const redact = (text: string) => text.replace(/[?#][\s\S]*/, (cut) => `${cut[0]}…`).slice(0, 300);

  const record = (line: string) => {
    log.push(`${elapsed()} ${line}`);
    if (log.length > 200) log.shift();
  };

  // An iframe's own navigation is issued before the frame has a URL, so it counts by itself.
  const fromEmbeddedFrame = (request: Request) => {
    try {
      const frame = request.frame();
      return (
        frame !== page.mainFrame() &&
        (request.isNavigationRequest() || externalUrl(frame.url()) !== null)
      );
    } catch {
      return false;
    }
  };

  // Page-level console and error events do not say which frame produced them. Chrome runs a
  // cross-site frame in its own process with its own browser session, which also replays what the
  // frame logged before the session was opened. The session outlives navigations, so each message
  // is kept only if the JavaScript context that produced it has a known non-Torus origin.
  const watchConsoleAndErrors = async (frame: Frame) => {
    const frameUrl = externalUrl(frame.url());
    if (frame === page.mainFrame() || !frameUrl || watchedFrames.has(frame)) return;
    watchedFrames.add(frame);

    try {
      const session = await page.context().newCDPSession(frame);
      const contextOrigins = new Map<number, string>();
      const externalContext = (contextId: number | undefined) =>
        contextId === undefined ? null : externalUrl(contextOrigins.get(contextId) ?? '');

      session.on('Runtime.executionContextCreated', ({ context }) => {
        contextOrigins.set(context.id, context.origin);
      });
      session.on('Runtime.executionContextDestroyed', ({ executionContextId }) => {
        contextOrigins.delete(executionContextId);
      });
      session.on('Runtime.executionContextsCleared', () => contextOrigins.clear());
      session.on('Runtime.consoleAPICalled', ({ type, args, stackTrace, executionContextId }) => {
        const context = externalContext(executionContextId);
        if (!context || (type !== 'error' && type !== 'warning')) return;
        const text = args
          .map((arg) =>
            arg.type === 'string' ? arg.value : (arg.description ?? String(arg.value)),
          )
          .join(' ');
        const url = externalUrl(stackTrace?.callFrames[0]?.url ?? '') ?? context;
        record(`console.${type} ${url}: ${redact(text)}`);
      });
      session.on('Runtime.exceptionThrown', ({ exceptionDetails }) => {
        const { exception, executionContextId, text, url } = exceptionDetails;
        const context = externalContext(executionContextId);
        if (!context) return;
        const message =
          exception?.description?.split('\n')[0] ??
          (exception && 'value' in exception ? String(exception.value) : text);
        record(`uncaught error ${externalUrl(url ?? '') ?? context}: ${redact(message)}`);
      });
      await session.send('Runtime.enable');
    } catch {
      if (!frame.isDetached()) record(`console and errors of ${frameUrl} could not be read`);
    }
  };

  page.on('framenavigated', (frame) => void watchConsoleAndErrors(frame));

  page.on('request', (request) => {
    const url = externalUrl(request.url());
    if (url && trackedTypes.has(request.resourceType()) && fromEmbeddedFrame(request)) {
      pending.set(request, { since: elapsed(), label: `${request.method()} ${url}` });
    }
  });

  page.on('requestfinished', async (request) => {
    const entry = pending.get(request);
    if (!entry) return;
    pending.delete(request);
    const response = await request.response().catch(() => null);
    const ms = Math.round(request.timing().responseEnd);
    record(`${entry.label} → ${response?.status() ?? '?'} in ${ms} ms`);
  });

  page.on('requestfailed', (request) => {
    const entry = pending.get(request);
    if (!entry) return;
    pending.delete(request);
    record(`${entry.label} → failed: ${request.failure()?.errorText}`);
  });

  return {
    dump: () =>
      [
        ...log,
        ...Array.from(
          pending.values(),
          ({ since, label }) => `${since} ${label} → still pending at ${elapsed()}`,
        ),
      ].join('\n') || 'nothing recorded',
  };
}
