import { expect, type Locator } from '@playwright/test';

/**
 * Student delivery helpers for logic lab activities.
 *
 * These helpers simulate the postMessage protocol used by the embedded lab so
 * delivery specs can exercise save, score, and restore behavior deterministically.
 */

export type LogicLabSaveState = {
  problemId: string;
  timestamp: string;
  data: {
    status: string;
    points: { score: number; outOf: number };
    best: { score: number; outOf: number };
    activityType: string;
    objectives: { name: string; complete: boolean; state: unknown }[];
  };
};

type LogicLabLoadPayload = {
  activity?: unknown;
  save?: string;
  state?: LogicLabSaveState;
  attemptGuid?: string;
};

export async function sendLogicLabSave(activity: Locator, state: LogicLabSaveState) {
  const iframe = logicLabIframe(activity);

  await expect(iframe).toBeVisible();

  await iframe.evaluate((node, state) => {
    const frame = node as HTMLIFrameElement;
    const attemptGuid = frame.dataset.oliAttemptGuid;

    if (!attemptGuid) {
      throw new Error('LogicLab iframe attempt guid was not available');
    }

    window.dispatchEvent(
      new MessageEvent('message', {
        origin: new URL(frame.src).origin,
        data: {
          attemptGuid,
          messageType: 'save',
          state,
        },
      }),
    );
  }, state);
}

export async function sendLogicLabScore(
  activity: Locator,
  score: { score: number; outOf: number; input: LogicLabSaveState; complete: boolean },
) {
  const iframe = logicLabIframe(activity);

  await expect(iframe).toBeVisible();

  await iframe.evaluate((node, score) => {
    const frame = node as HTMLIFrameElement;
    const attemptGuid = frame.dataset.oliAttemptGuid;

    if (!attemptGuid) {
      throw new Error('LogicLab iframe attempt guid was not available');
    }

    window.dispatchEvent(
      new MessageEvent('message', {
        origin: new URL(frame.src).origin,
        data: {
          attemptGuid,
          messageType: 'score',
          score,
        },
      }),
    );
  }, score);
}

export async function requestLogicLabLoad(activity: Locator): Promise<LogicLabLoadPayload | null> {
  const iframe = logicLabIframe(activity);

  await expect(iframe).toBeVisible();

  return iframe.evaluate(async (node) => {
    const frame = node as HTMLIFrameElement;
    const attemptGuid = frame.dataset.oliAttemptGuid;

    if (!attemptGuid) {
      throw new Error('LogicLab iframe attempt guid was not available');
    }

    const channel = new MessageChannel();
    const payloadPromise = new Promise<LogicLabLoadPayload | null>((resolve) => {
      channel.port1.onmessage = (event) => {
        resolve((event.data as LogicLabLoadPayload) ?? null);
      };
    });

    window.dispatchEvent(
      new MessageEvent('message', {
        origin: new URL(frame.src).origin,
        source: channel.port2,
        data: {
          attemptGuid,
          messageType: 'load',
        },
      }),
    );

    return payloadPromise;
  });
}

export function logicLabIframe(activity: Locator) {
  return activity.locator('iframe[data-oli-attempt-guid]').first();
}
