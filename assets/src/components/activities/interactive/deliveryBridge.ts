import { DeliveryElementProps } from '../DeliveryElement';
import { InteractiveModelSchema } from './schema';

export const INTERACTIVE_CHANNEL = 'torus.interactive.v1';
export class InteractiveError extends Error {}
export type InteractiveRequestHandler = (request: {
  method: string;
  params?: any;
}) => Promise<unknown>;
type DeliveryContext = Pick<
  DeliveryElementProps<InteractiveModelSchema>,
  'context' | 'state' | 'mode'
>;
const reads = new Set(['context', 'attempt.get', 'section.get']);
const methods = new Set([
  ...reads,
  'attempt.set',
  'section.set',
  'parts.finalize',
  'activity.finalize',
]);

/** Uses Torus-owned delivery context for authenticated persistence and read-only review. */
export function createDeliveryHandler(delivery: DeliveryContext): InteractiveRequestHandler {
  return async (request) => {
    if (delivery.mode !== 'delivery' && !reads.has(request.method)) {
      throw new InteractiveError('read_only');
    }
    if (!delivery.context.sectionSlug || !delivery.state.attemptGuid) {
      throw new InteractiveError('unavailable');
    }
    const path = `/api/v1/state/course/${encodeURIComponent(
      delivery.context.sectionSlug,
    )}/activity_attempt/${encodeURIComponent(delivery.state.attemptGuid)}/interactive`;
    const read = reads.has(request.method);
    const query = new URLSearchParams({ method: request.method });
    if (request.params?.key !== undefined) query.set('key', request.params.key);
    const result = await fetch(read ? `${path}?${query}` : path, {
      method: read ? 'GET' : 'POST',
      credentials: 'same-origin',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      ...(read
        ? {}
        : { body: JSON.stringify({ version: 1, method: request.method, params: request.params }) }),
    });
    const body = await result.json();
    if (!result.ok) throw new InteractiveError(body.error?.code || 'request_failed');
    return request.method === 'context' && delivery.mode !== 'delivery'
      ? { ...body.result, readOnly: true }
      : body.result;
  };
}

/** Accepts requests only from this frame and origin, independent of the capability implementation. */
export function attachInteractiveBridge(
  frame: HTMLIFrameElement,
  mediaOrigin: string,
  execute: InteractiveRequestHandler,
  onResize?: (height: number) => void,
): () => void {
  const origin = mediaOrigin === window.location.origin ? 'null' : mediaOrigin;
  let attached = true;
  const pending = new Set<string>();
  const handle = async (event: MessageEvent) => {
    const request = event.data;
    if (
      event.source !== frame.contentWindow ||
      event.origin !== origin ||
      !request ||
      request.channel !== INTERACTIVE_CHANNEL
    )
      return;
    if (request.type === 'resize') {
      if (
        typeof request.height === 'number' &&
        Number.isFinite(request.height) &&
        request.height > 0
      ) {
        onResize?.(Math.min(Math.ceil(request.height), 100_000));
      }
      return;
    }
    if (
      typeof request.id !== 'string' ||
      request.id.length > 128 ||
      !methods.has(request.method) ||
      pending.has(request.id)
    )
      return;
    pending.add(request.id);
    let response: { result?: unknown; error?: { code: string } };
    try {
      response = { result: await execute(request) };
    } catch (error) {
      response = {
        error: { code: error instanceof InteractiveError ? error.message : 'request_failed' },
      };
    }
    pending.delete(request.id);
    if (attached) {
      frame.contentWindow?.postMessage(
        { channel: INTERACTIVE_CHANNEL, id: request.id, ...response },
        origin === 'null' ? '*' : origin,
      );
    }
  };
  window.addEventListener('message', handle);
  return () => {
    attached = false;
    window.removeEventListener('message', handle);
  };
}
