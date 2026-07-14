import { type FrameLocator, type Locator, type Page, expect } from '@playwright/test';

/**
 * Student delivery helpers for embedded activities.
 *
 * These helpers centralize iframe access and Torus attempt-state lookups so
 * specs can focus on activity behavior instead of embedded-runtime plumbing.
 */

type EmbeddedPartState = {
  attemptGuid: string;
  partId: string;
  score: number | null;
  outOf: number | null;
  dateEvaluated: string | null;
  dateSubmitted: string | null;
  response: unknown | null;
  feedback: unknown | null;
};

type EmbeddedAttemptStateResponse = {
  state: {
    attemptGuid: string;
    attemptNumber: number;
    dateEvaluated: string | null;
    dateSubmitted: string | null;
    lifecycle_state: string;
    score: number | null;
    outOf: number | null;
    parts: EmbeddedPartState[];
  };
};

export function embeddedActivity(page: Page): Locator {
  return page.locator('oli-embedded-delivery').first();
}

export function embeddedIframe(activity: Locator): Locator {
  return activity.locator('iframe[data-resourcetypeid="oli_embedded"]').first();
}

export function embeddedRuntimeFrame(page: Page): FrameLocator {
  return page.frameLocator('iframe[data-resourcetypeid="oli_embedded"]').first();
}

export function embeddedRuntimeElement(frame: FrameLocator, id: string): Locator {
  return frame.locator(`#${id}`);
}

export async function embeddedAttemptGuid(activity: Locator): Promise<string> {
  return readEmbeddedActivityState(activity, 'attemptGuid');
}

export async function embeddedAttemptNumber(activity: Locator): Promise<number> {
  return readEmbeddedActivityState(activity, 'attemptNumber');
}

export async function getEmbeddedAttemptState(
  page: Page,
  sectionSlug: string,
  attemptGuid: string,
): Promise<EmbeddedAttemptStateResponse['state']> {
  // Read the attempt state through Torus' public state API so delivery tests
  // can verify persistence/evaluation without reaching into the database.
  const response = await page.evaluate(
    async ({ sectionSlug, attemptGuid }) => {
      const apiResponse = await fetch(
        `/api/v1/state/course/${sectionSlug}/activity_attempt/${attemptGuid}`,
      );

      if (!apiResponse.ok) {
        throw new Error(`Failed to fetch activity attempt state: ${apiResponse.status}`);
      }

      return apiResponse.json();
    },
    { sectionSlug, attemptGuid },
  );

  return (response as EmbeddedAttemptStateResponse).state;
}

export async function expectEmbeddedAttemptEventually(
  page: Page,
  sectionSlug: string,
  attemptGuid: string,
  predicate: (state: EmbeddedAttemptStateResponse['state']) => boolean,
  message: string,
) {
  await expect
    .poll(
      async () => {
        const state = await getEmbeddedAttemptState(page, sectionSlug, attemptGuid);
        return predicate(state);
      },
      { message },
    )
    .toBe(true);
}

async function readEmbeddedActivityState<T extends 'attemptGuid' | 'attemptNumber'>(
  activity: Locator,
  key: T,
) {
  const state = await activity.getAttribute('state');

  if (!state) {
    throw new Error('Embedded activity is missing state payload');
  }

  return (JSON.parse(state) as Record<T, T extends 'attemptNumber' ? number : string>)[key];
}
