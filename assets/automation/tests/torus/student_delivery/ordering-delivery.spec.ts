import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import {
  configureStudentDeliveryRuntimeConfig,
  openStudentDeliveryPractice,
  seedStudentDeliveryScenario,
} from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './ordering-delivery.scenario.yaml');
const activityTitle = 'Ordering Practice';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'ordering-delivery-student',
    welcomeTitle: 'Hi, Ordering',
    name: 'Ordering',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'ordering-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'ordering-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'ordering-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: { negative: string; positive: string };

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    positive: outputs.sections?.ordering_delivery_section ?? '',
    negative: outputs.sections?.ordering_delivery_section_negative ?? '',
  };

  expect(sections.positive).toBeTruthy();
  expect(sections.negative).toBeTruthy();
});

test.describe('ordering delivery', () => {
  test('student can reorder choices and submit the correct sequence', async ({
    homeTask,
    page,
  }) => {
    await openStudentDeliveryPractice(homeTask, page, sections.positive, activityTitle);
    const activity = page.locator('.activity.ordering-activity');
    const firstChoice = page.getByLabel('choice 1', { exact: true });
    const submitButton = page.getByRole('button', { name: 'submit', exact: true });

    await expect(activity).toBeVisible();
    await expect(firstChoice).toContainText('Third');

    await firstChoice.click();
    await firstChoice.focus();
    await page.keyboard.down('Shift');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.up('Shift');

    await expect(page.getByLabel('choice 1', { exact: true })).toContainText('First');
    await expect(page.getByLabel('choice 2', { exact: true })).toContainText('Second');
    await expect(page.getByLabel('choice 3', { exact: true })).toContainText('Third');

    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(page.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(page.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. You ordered the steps correctly.',
    );
    await expect(page.getByLabel('result')).toHaveCount(1);
  });

  test('student submitting the default order sees incorrect feedback', async ({
    homeTask,
    page,
  }) => {
    await openStudentDeliveryPractice(homeTask, page, sections.negative, activityTitle);
    const activity = page.locator('.activity.ordering-activity');
    const submitButton = page.getByRole('button', { name: 'submit', exact: true });

    await expect(activity).toBeVisible();
    await expect(page.getByLabel('choice 1', { exact: true })).toContainText('Third');
    await expect(page.getByLabel('choice 2', { exact: true })).toContainText('First');
    await expect(page.getByLabel('choice 3', { exact: true })).toContainText('Second');

    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(page.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(page.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );
    await expect(page.locator('.evaluation.feedback.correct')).toHaveCount(0);
  });
});
