import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';
import { clickImageHotspot } from './support/imageHotspot';
import {
  configureStudentDeliveryRuntimeConfig,
  seedStudentDeliveryScenario,
} from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './image-hotspot-delivery.scenario.yaml');
const activityTitle = 'Image Hotspot Practice';
const singleStem = 'Select the green target hotspot.';
const multiStem = 'Select both blue target hotspots.';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'image-hotspot-delivery-student',
    welcomeTitle: 'Hi, Image',
    name: 'Image',
    lastName: 'Hotspot Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'image-hotspot-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'image-hotspot-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'image-hotspot-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: Record<string, string>;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    singleCorrect: outputs.sections?.image_hotspot_delivery_section_single_correct ?? '',
    singleIncorrect: outputs.sections?.image_hotspot_delivery_section_single_incorrect ?? '',
    multiCorrect: outputs.sections?.image_hotspot_delivery_section_multi_correct ?? '',
    multiPartial: outputs.sections?.image_hotspot_delivery_section_multi_partial ?? '',
    multiExtra: outputs.sections?.image_hotspot_delivery_section_multi_extra ?? '',
    multiReset: outputs.sections?.image_hotspot_delivery_section_multi_reset ?? '',
    multiRestore: outputs.sections?.image_hotspot_delivery_section_multi_restore ?? '',
  };

  Object.values(sections).forEach((section) => expect(section).toBeTruthy());
});

test.describe('image hotspot delivery', () => {
  test('single-select hotspot variants auto-submit and show the expected feedback', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.singleCorrect,
      activityTitle,
    );
    let activity = imageHotspotActivity(page, singleStem);

    // Correct single-select path.
    await expect(activity).toBeVisible();
    await expect(activity.getByRole('button', { name: 'submit', exact: true })).toHaveCount(0);

    await clickImageHotspot(activity, 'Single target hotspot');

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. You selected the target hotspot.',
    );
    await expect(activity.getByLabel('result')).toHaveCount(1);

    // Incorrect single-select path.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.singleIncorrect,
      activityTitle,
    );
    activity = imageHotspotActivity(page, singleStem);

    await expect(activity).toBeVisible();

    await clickImageHotspot(activity, 'Single distractor hotspot');

    await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );
    await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);
  });

  test('multi-select hotspot evaluation variants show the expected outcomes', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');
    await openStudentDeliveryPracticeForLoggedInStudent(page, sections.multiCorrect, activityTitle);
    let activity = imageHotspotActivity(page, multiStem);
    let submitButton = activity.getByRole('button', { name: 'submit', exact: true });

    // Multi-select: all correct choices.
    await expect(activity).toBeVisible();
    await expect(submitButton).toBeDisabled();

    await clickImageHotspot(activity, 'First multi target hotspot');
    await clickImageHotspot(activity, 'Second multi target hotspot');

    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. You selected both target hotspots.',
    );

    // Multi-select: partial selection stays incorrect.
    await openStudentDeliveryPracticeForLoggedInStudent(page, sections.multiPartial, activityTitle);
    activity = imageHotspotActivity(page, multiStem);
    submitButton = activity.getByRole('button', { name: 'submit', exact: true });

    await clickImageHotspot(activity, 'First multi target hotspot');
    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );

    // Multi-select: extra incorrect choice also evaluates as incorrect.
    await openStudentDeliveryPracticeForLoggedInStudent(page, sections.multiExtra, activityTitle);
    activity = imageHotspotActivity(page, multiStem);
    submitButton = activity.getByRole('button', { name: 'submit', exact: true });

    await clickImageHotspot(activity, 'First multi target hotspot');
    await clickImageHotspot(activity, 'Second multi target hotspot');
    await clickImageHotspot(activity, 'Multi distractor hotspot');
    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );
  });

  test('multi-select hotspot persistence variants support reset and restore', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');
    await openStudentDeliveryPracticeForLoggedInStudent(page, sections.multiReset, activityTitle);
    let activity = imageHotspotActivity(page, multiStem);
    let submitButton = activity.getByRole('button', { name: 'submit', exact: true });
    const resetButton = activity.getByRole('button', { name: 'reset', exact: true });

    // Multi-select: reset clears evaluated state.
    await clickImageHotspot(activity, 'First multi target hotspot');
    await clickImageHotspot(activity, 'Second multi target hotspot');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(resetButton).toBeVisible();

    await resetButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);
    await expect(activity.locator('.evaluation.feedback.incorrect')).toHaveCount(0);
    await expect(submitButton).toBeDisabled();

    // Multi-select: evaluated state restores after reload.
    await openStudentDeliveryPracticeForLoggedInStudent(page, sections.multiRestore, activityTitle);
    activity = imageHotspotActivity(page, multiStem);
    submitButton = activity.getByRole('button', { name: 'submit', exact: true });

    await clickImageHotspot(activity, 'First multi target hotspot');
    await clickImageHotspot(activity, 'Second multi target hotspot');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();

    await page.reload({ waitUntil: 'load' });

    activity = imageHotspotActivity(page, multiStem);

    await expect(activity).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. You selected both target hotspots.',
    );
    await expect(activity.getByRole('button', { name: 'submit', exact: true })).toBeDisabled();
  });
});

function imageHotspotActivity(page: Page, stem: string) {
  return page
    .locator('.activity.multiple-choice-activity')
    .filter({ has: page.getByText(stem, { exact: true }) })
    .first();
}
