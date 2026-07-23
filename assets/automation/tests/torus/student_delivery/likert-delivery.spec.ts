import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';
import { likertActivity, likertRadios, likertSubmit } from './support/likert';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './likert-delivery.scenario.yaml');
const activityTitle = 'Likert Practice';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'likert-delivery-student',
    welcomeTitle: 'Hi, Likert',
    name: 'Likert',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'likert-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'likert-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'likert-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: Record<string, string>;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    happy: outputs.sections?.likert_delivery_section ?? '',
    gating: outputs.sections?.likert_delivery_section_gating ?? '',
    restore: outputs.sections?.likert_delivery_section_restore ?? '',
  };

  Object.values(sections).forEach((section) => expect(section).toBeTruthy());
});

test.describe('likert delivery', () => {
  test('likert gates submit until a scale is selected and evaluates on submit', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    await test.step('submit is disabled until a scale point is selected', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.gating, activityTitle);
      const activity = likertActivity(page);
      const firstChoice = likertRadios(activity).first();
      const submitButton = likertSubmit(activity);

      await expect(activity).toBeVisible();
      await expect(submitButton).toBeDisabled();

      await firstChoice.click();

      await expect(firstChoice).toBeChecked();
      await expect(submitButton).toBeEnabled();
    });

    await test.step('selecting a scale point and submitting shows an evaluated result', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.happy, activityTitle);
      const activity = likertActivity(page);
      const firstChoice = likertRadios(activity).first();
      const submitButton = likertSubmit(activity);

      await expect(activity).toBeVisible();
      await firstChoice.click();
      await expect(firstChoice).toBeChecked();

      await expect(submitButton).toBeEnabled();
      await submitButton.click();

      await expect(page.getByLabel('result')).toHaveCount(1);
      await expect(likertRadios(activity).first()).toBeDisabled();
    });
  });

  test('likert restores the evaluated selection after reload', async ({ homeTask, page }) => {
    await homeTask.login('student');

    await test.step('submitted selection persists as checked and disabled after reload', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.restore, activityTitle);
      const activity = likertActivity(page);
      const firstChoice = likertRadios(activity).first();
      const submitButton = likertSubmit(activity);

      await expect(activity).toBeVisible();
      await firstChoice.click();
      await submitButton.click();
      await expect(page.getByLabel('result')).toHaveCount(1);

      await page.reload({ waitUntil: 'load' });

      const restoredChoice = likertRadios(likertActivity(page)).first();
      await expect(restoredChoice).toBeChecked();
      await expect(restoredChoice).toBeDisabled();
    });
  });
});
