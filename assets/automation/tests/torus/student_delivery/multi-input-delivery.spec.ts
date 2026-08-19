import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import {
  configureStudentDeliveryRuntimeConfig,
  openStudentDeliveryPractice,
  seedStudentDeliveryScenario,
} from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './multi-input-delivery.scenario.yaml');
const activityTitle = 'Multi Input Practice';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'multi-input-delivery-student',
    welcomeTitle: 'Hi, Multi Input',
    name: 'Multi Input',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'multi-input-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'multi-input-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'multi-input-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: { negative: string; positive: string };

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    positive: outputs.sections?.multi_input_delivery_section ?? '',
    negative: outputs.sections?.multi_input_delivery_section_negative ?? '',
  };

  expect(sections.positive).toBeTruthy();
  expect(sections.negative).toBeTruthy();
});

test.describe('multi-input delivery', () => {
  test('student can fill all blanks, submit, and see correct feedback', async ({
    homeTask,
    page,
  }) => {
    await openStudentDeliveryPractice(homeTask, page, sections.positive, activityTitle);
    const activity = page.locator('.activity.multi-input-activity');
    const inputs = activity.getByLabel('answer submission textbox');
    const dropdown = activity.getByRole('combobox');
    const submitButton = page.getByRole('button', { name: /^submit$/i });

    await expect(activity).toBeVisible();
    await expect(inputs).toHaveCount(2);
    await expect(dropdown).toBeVisible();

    await inputs.nth(0).fill('answer');
    await inputs.nth(1).fill('42');
    await dropdown.selectOption('choice_correct');

    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(page.locator('.evaluation.feedback.correct')).toHaveCount(3);
    await expect(page.getByLabel('result')).toHaveCount(3);
  });

  test('student filling an incorrect blank sees incorrect feedback', async ({ homeTask, page }) => {
    await openStudentDeliveryPractice(homeTask, page, sections.negative, activityTitle);
    const activity = page.locator('.activity.multi-input-activity');
    const inputs = activity.getByLabel('answer submission textbox');
    const dropdown = activity.getByRole('combobox');
    const submitButton = page.getByRole('button', { name: /^submit$/i });

    await expect(activity).toBeVisible();
    await expect(inputs).toHaveCount(2);
    await expect(dropdown).toBeVisible();

    await inputs.nth(0).fill('wrong');
    await inputs.nth(1).fill('7');
    await dropdown.selectOption('choice_incorrect');

    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(page.locator('.evaluation.feedback.incorrect')).toHaveCount(3);
    await expect(page.locator('.evaluation.feedback.correct')).toHaveCount(0);
  });
});
