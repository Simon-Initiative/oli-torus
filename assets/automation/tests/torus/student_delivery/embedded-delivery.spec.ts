import { test } from '@fixture/my-fixture';
import { expect } from '@playwright/test';
import path from 'node:path';
import {
  configureStudentDeliveryRuntimeConfig,
  embeddedActivity,
  embeddedAttemptGuid,
  embeddedAttemptNumber,
  embeddedIframe,
  embeddedRuntimeElement,
  embeddedRuntimeFrame,
  expectEmbeddedAttemptEventually,
  getEmbeddedAttemptState,
  seedStudentDeliveryScenario,
} from './support';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './embedded-delivery.scenario.yaml');
const activityTitle = 'Embedded Practice';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'embedded-delivery-student',
    welcomeTitle: 'Hi, Embedded',
    name: 'Embedded',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'embedded-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'embedded-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'embedded-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sectionSlug: string;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);
  sectionSlug = outputs.sections?.embedded_delivery_section_launch ?? '';
  expect(sectionSlug).toBeTruthy();
});

/**
 * These tests validate Torus-side embedded delivery behavior with a deterministic
 * local runtime shell served from `/superactivity/embedded/index.html`.
 *
 * The stub lets us verify launch context, save/load plumbing, and legacy
 * superactivity commands against real Torus attempt state without depending on
 * object-storage-hosted custom bundles.
 */
test.describe('embedded delivery', () => {
  test('embedded activity launches and its runtime commands mutate Torus attempt state', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    let initialAttemptGuid = '';
    let initialAttemptNumber = 0;

    await test.step(
      'embedded activity initializes context and renders the runtime iframe',
      async () => {
        await openStudentDeliveryPracticeForLoggedInStudent(page, sectionSlug, activityTitle);
        const activity = embeddedActivity(page);
        const iframe = embeddedIframe(activity);

        await expect(activity).toBeVisible();
        await expect(
          activity.getByText('Unable to initialize the embedded activity context', {
            exact: false,
          }),
        ).toHaveCount(0);
        await expect(iframe).toBeVisible();
        await expect(iframe).toHaveAttribute('src', /\/superactivity\/embedded\/index\.html/);
        await expect(iframe).toHaveAttribute('data-resourcetypeid', 'oli_embedded');
        await expect(iframe).toHaveAttribute('data-activitymode', 'delivery');
        await expect(iframe).toHaveAttribute('data-mode', 'oli');

        await expect
          .poll(async () => iframe.evaluate((node) => getComputedStyle(node).opacity), {
            message: 'Expected the embedded runtime iframe to finish loading',
          })
          .toBe('1');

        await expect(activity.getByText('Loading embedded activity', { exact: false })).toHaveCount(
          0,
        );

        const runtime = embeddedRuntimeFrame(page);
        await expect(
          runtime.getByRole('heading', { name: 'Embedded runtime stub loaded' }),
        ).toBeVisible();
        await expect(runtime.locator('html')).toHaveAttribute('data-embedded-stub', 'ready');
        await expect(embeddedRuntimeElement(runtime, 'activity-mode')).toHaveText('delivery');
        await expect(embeddedRuntimeElement(runtime, 'resource-type')).toHaveText('oli_embedded');
        await expect(embeddedRuntimeElement(runtime, 'attempt-guid')).not.toHaveText('unknown');

        initialAttemptGuid = await embeddedAttemptGuid(activity);
        initialAttemptNumber = await embeddedAttemptNumber(activity);

        await expect(embeddedRuntimeElement(runtime, 'attempt-guid')).toHaveText(
          initialAttemptGuid,
        );
        await expect(embeddedRuntimeElement(runtime, 'attempt-number')).toHaveText(
          String(initialAttemptNumber),
        );
      },
    );

    await test.step(
      'embedded runtime startAttempt preserves the current active attempt',
      async () => {
        const runtime = embeddedRuntimeFrame(page);

        // Active attempts should not rotate yet; the legacy command simply returns the current one.
        await embeddedRuntimeElement(runtime, 'start-attempt').click();
        await expect(embeddedRuntimeElement(runtime, 'command-status')).toHaveText(
          'startAttempt succeeded',
        );
        await expect(embeddedRuntimeElement(runtime, 'attempt-number')).toHaveText(
          String(initialAttemptNumber),
        );

        await expectEmbeddedAttemptEventually(
          page,
          sectionSlug,
          initialAttemptGuid,
          (state) =>
            state.lifecycle_state === 'active' && state.attemptNumber === initialAttemptNumber,
          'Expected startAttempt to keep the initial embedded attempt active',
        );
      },
    );

    await test.step('embedded runtime writes and loads a save file through Torus', async () => {
      const runtime = embeddedRuntimeFrame(page);

      // Persist deterministic save data from the stub, then load it back through the same API.
      await embeddedRuntimeElement(runtime, 'write-file-record').click();
      await expect(embeddedRuntimeElement(runtime, 'command-status')).toHaveText(
        'writeFileRecord succeeded',
      );
      await expect(embeddedRuntimeElement(runtime, 'loaded-record-status')).toHaveText(
        'Saved file record to Torus.',
      );

      await embeddedRuntimeElement(runtime, 'load-file-record').click();
      await expect(embeddedRuntimeElement(runtime, 'command-status')).toHaveText(
        'loadFileRecord succeeded',
      );
      await expect(embeddedRuntimeElement(runtime, 'loaded-record-status')).toHaveText(
        'Loaded file record from Torus.',
      );
      await expect(embeddedRuntimeElement(runtime, 'loaded-record')).toContainText(
        'saved-from-stub',
      );
    });

    await test.step('embedded runtime scoreAttempt changes the Torus attempt state', async () => {
      const runtime = embeddedRuntimeFrame(page);
      const beforeScoreState = await getEmbeddedAttemptState(page, sectionSlug, initialAttemptGuid);

      // Client-side scoring should mutate Torus attempt state, even before the attempt is finalized.
      await embeddedRuntimeElement(runtime, 'score-attempt').click();
      await expect(embeddedRuntimeElement(runtime, 'command-status')).toHaveText(
        'scoreAttempt succeeded',
      );

      await expectEmbeddedAttemptEventually(
        page,
        sectionSlug,
        initialAttemptGuid,
        (state) =>
          state.parts[0]?.score === 75 &&
          state.parts[0]?.outOf === 100 &&
          JSON.stringify(state.parts[0]) !== JSON.stringify(beforeScoreState.parts[0]),
        'Expected scoreAttempt to change the embedded Torus attempt state',
      );
    });

    await test.step('embedded runtime endAttempt finalizes the Torus attempt state', async () => {
      const runtime = embeddedRuntimeFrame(page);

      // Finalization should roll the scored part state up to the activity attempt in Torus.
      await embeddedRuntimeElement(runtime, 'end-attempt').click();
      await expect(embeddedRuntimeElement(runtime, 'command-status')).toHaveText(
        'endAttempt succeeded',
      );

      await expectEmbeddedAttemptEventually(
        page,
        sectionSlug,
        initialAttemptGuid,
        (state) =>
          state.lifecycle_state === 'evaluated' &&
          state.score === 75 &&
          state.outOf === 100 &&
          state.dateEvaluated !== null,
        'Expected endAttempt to finalize the embedded Torus attempt state',
      );
    });

    await test.step(
      'embedded runtime startAttempt opens the next attempt after the prior one ends',
      async () => {
        const runtime = embeddedRuntimeFrame(page);

        // Once evaluated, startAttempt should advance the embedded flow to the next attempt number.
        await embeddedRuntimeElement(runtime, 'start-attempt').click();
        await expect(embeddedRuntimeElement(runtime, 'command-status')).toHaveText(
          'startAttempt succeeded',
        );
        await expect(embeddedRuntimeElement(runtime, 'attempt-number')).toHaveText('2');
      },
    );

    await test.step('embedded activity reloads against the new active Torus attempt', async () => {
      await page.reload({ waitUntil: 'load' });

      const activity = embeddedActivity(page);
      const iframe = embeddedIframe(activity);

      await expect(activity).toBeVisible();
      await expect(iframe).toBeVisible();
      await expect
        .poll(async () => iframe.evaluate((node) => getComputedStyle(node).opacity), {
          message: 'Expected the embedded runtime iframe to finish loading after reload',
        })
        .toBe('1');
      await expect(activity.getByText('Loading embedded activity', { exact: false })).toHaveCount(
        0,
      );

      const runtime = embeddedRuntimeFrame(page);
      const reloadedAttemptGuid = await embeddedAttemptGuid(activity);
      const reloadedAttemptNumber = await embeddedAttemptNumber(activity);

      await expect(
        runtime.getByRole('heading', { name: 'Embedded runtime stub loaded' }),
      ).toBeVisible();
      await expect(runtime.locator('html')).toHaveAttribute('data-embedded-stub', 'ready');
      await expect(reloadedAttemptGuid).not.toBe(initialAttemptGuid);
      await expect(reloadedAttemptNumber).toBe(2);
      await expect(embeddedRuntimeElement(runtime, 'attempt-guid')).toHaveText(reloadedAttemptGuid);

      // The launch payload includes the new attempt guid, but not the attempt number.
      // The stub only learns the attempt number after a legacy command returns attempt history,
      // so the durable assertion here is against Torus attempt state, not the stub label.
      await expectEmbeddedAttemptEventually(
        page,
        sectionSlug,
        reloadedAttemptGuid,
        (state) => state.lifecycle_state === 'active' && state.attemptNumber === 2,
        'Expected reload to bind the embedded runtime to the new active Torus attempt',
      );
    });
  });
});
