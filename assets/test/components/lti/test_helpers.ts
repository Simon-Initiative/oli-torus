import { act, waitFor } from '@testing-library/react';

/** Lets each test decide when its simulated request completes or fails. */
export function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((ok, fail) => {
    resolve = ok;
    reject = fail;
  });
  return { promise, resolve, reject };
}

export function message(frame: HTMLIFrameElement, data: unknown, origin = window.location.origin) {
  act(() => {
    window.dispatchEvent(
      new MessageEvent('message', { source: frame.contentWindow, origin, data }),
    );
  });
}

export function waitForFrame(container: HTMLElement) {
  return waitFor(() => {
    const frame = container.querySelector('iframe');
    expect(frame).not.toBeNull();
    return frame!;
  });
}

/** Registers Bootstrap stubbing and restoration only in the suite that calls it. */
export function mockBootstrapModal() {
  type HideEvent = { preventDefault: () => void };
  const handlers = new Map<Element, (event: HideEvent) => void>();
  const originals = [window, global].map((target) => ({
    target,
    descriptor: Object.getOwnPropertyDescriptor(target, '$'),
  }));
  const jquery = (element: Element) => ({
    modal: () => undefined,
    on: (name: string, handler: (event: HideEvent) => void) => {
      if (name === 'hide.bs.modal') handlers.set(element, handler);
    },
  });

  beforeAll(() => {
    originals.forEach(({ target }) => {
      Object.defineProperty(target, '$', { configurable: true, writable: true, value: jquery });
    });
  });
  beforeEach(() => handlers.clear());
  afterAll(() => {
    originals.forEach(({ target, descriptor }) => {
      if (descriptor) Object.defineProperty(target, '$', descriptor);
      else Reflect.deleteProperty(target, '$');
    });
    handlers.clear();
  });

  return (dialog: Element, event = { preventDefault: jest.fn() }) => {
    act(() => handlers.get(dialog)!(event));
    return event;
  };
}
