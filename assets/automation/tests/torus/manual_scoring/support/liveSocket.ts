import { expect, type Page } from '@playwright/test';

/**
 * Puts LiveView's server → page messages behind a gate the test controls, so a test can act
 * "before the reply" without racing a timer. While held, each socket's messages wait in one FIFO
 * queue: `flush()` delivers what is queued and keeps holding, `release()` delivers it and opens the
 * gate. With the gate open a message passes only when nothing older waits, so order never changes.
 * Every message the page sends is kept, decoded, in `sent` — what an action asked the server for.
 *
 * Register it before the page that needs it opens its socket.
 */
export async function holdLiveViewReplies(page: Page) {
  // Each held message keeps the ref it answers, so a test can let one reply through by name.
  const queues: Array<Array<Held>> = [];
  const drain = () => {
    for (const queue of queues) while (queue.length) queue.shift()!.deliver();
  };
  const lastRef = (name: string) =>
    [...gate.sent].reverse().find((s) => s.name === name || s.event === name)?.ref;

  const gate = {
    held: false,
    sent: [] as SentEvent[],
    hold() {
      gate.held = true;
    },
    flush() {
      drain();
    },
    /** Delivers the oldest held message only, and keeps holding. */
    step() {
      queues
        .find((queue) => queue.length)
        ?.shift()
        ?.deliver();
    },
    /** Whether the reply to the last `name` event the page sent is waiting behind the gate. */
    holdsReplyTo(name: string) {
      const ref = lastRef(name);

      return !!ref && queues.some((queue) => queue.some((held) => held.ref === ref));
    },
    /**
     * Delivers, in order, every held message up to the reply to the last `name` event; keeps holding.
     * Refs count per socket: meant for a page with one LiveView socket, as in these specs.
     */
    deliverReplyTo(name: string) {
      const ref = lastRef(name);

      for (const queue of queues) {
        const index = queue.findIndex((held) => held.ref === ref);

        if (index >= 0) {
          queue.splice(0, index + 1).forEach((held) => held.deliver());
          return;
        }
      }
    },
    release() {
      gate.held = false;
      drain();
    },
    /** Server messages waiting behind the gate, for sockets still open. */
    pending() {
      return queues.reduce((count, queue) => count + queue.length, 0);
    },
  };

  await page.routeWebSocket(/live\/websocket/, (ws) => {
    const server = ws.connectToServer();
    const queue: Array<Held> = [];
    // A socket the page already closed (a full navigation) cannot take messages any more.
    const deliver = (message: string | Buffer) => () => {
      try {
        ws.send(message);
      } catch {
        // dropped with its socket
      }
    };

    queues.push(queue);
    // A socket the page closed takes nothing more: forget what it still held. Handling the close
    // turns off Playwright's own forwarding, so close the server side here.
    ws.onClose((code, reason) => {
      queues.splice(queues.indexOf(queue), 1);
      void server.close({ code, reason });
    });
    ws.onMessage((message) => {
      gate.sent.push(decode(message.toString()));
      server.send(message);
    });
    server.onMessage((message) => {
      if (gate.held || queue.length) {
        queue.push({ deliver: deliver(message), ref: decode(message.toString()).ref });
      } else ws.send(message);
    });
  });

  return gate;
}

/**
 * A channel message: its event, its ref (a reply carries the ref of the message it answers), and for
 * `event` messages the LiveView event name.
 */
export type SentEvent = { event: string; name?: string; ref?: string };
type Held = { deliver: () => void; ref?: string };

function decode(frame: string): SentEvent {
  try {
    const [, ref, , event, payload] = JSON.parse(frame);

    return { event, ref, name: event === 'event' ? payload?.event : undefined };
  } catch {
    return { event: 'unknown' };
  }
}

/**
 * LiveView events and live patches the page sent since `from` (an index into `gate.sent`). Live
 * redirects are not listed: the scoring page has no `navigate` links.
 */
export function sentSince(gate: { sent: SentEvent[] }, from: number) {
  return gate.sent
    .slice(from)
    .filter((s) => s.event === 'live_patch' || s.event === 'event')
    .map((s) => s.name ?? s.event);
}

export async function waitForLiveView(page: Page) {
  await expect(page.locator('[data-phx-main].phx-connected')).toBeAttached({ timeout: 20_000 });
}

export async function disconnectLiveView(page: Page) {
  await page.evaluate(() => (window as any).liveSocket.disconnect());
  await expect(page.locator('[data-phx-main].phx-connected')).toHaveCount(0);
}

export async function reconnectLiveView(page: Page) {
  await page.evaluate(() => (window as any).liveSocket.connect());
  await waitForLiveView(page);
}

/** Records the type of every native dialog (`beforeunload`, `confirm`, …) and dismisses it. */
export function recordDialogs(page: Page) {
  const dialogs: string[] = [];

  page.on('dialog', (dialog) => {
    dialogs.push(dialog.type());
    void dialog.dismiss();
  });

  return dialogs;
}
