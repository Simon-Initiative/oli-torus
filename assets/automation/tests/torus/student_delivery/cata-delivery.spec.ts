import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import {
  configureStudentDeliveryRuntimeConfig,
  openStudentDeliveryPractice,
  seedStudentDeliveryScenario,
} from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './cata-delivery.scenario.yaml');

const activityTitle = 'CATA Practice';
configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'cata-delivery-student',
    welcomeTitle: 'Hi, CATA',
    name: 'CATA',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'cata-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'cata-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'cata-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: { positive: string; negative: string };

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    positive: outputs.sections?.cata_delivery_section ?? '',
    negative: outputs.sections?.cata_delivery_section_negative ?? '',
  };

  expect(sections.positive).toBeTruthy();
  expect(sections.negative).toBeTruthy();
});

test.describe('CATA delivery', () => {
  test('student can select multiple correct answers, submit, and see feedback', async ({
    homeTask,
    page,
  }) => {
    await openStudentDeliveryPractice(homeTask, page, sections.positive, activityTitle);
    const activity = page.locator('.activity.cata-activity');
    const choiceOne = page.getByRole('checkbox', { name: 'choice 1', exact: true });
    const choiceTwo = page.getByRole('checkbox', { name: 'choice 2', exact: true });
    const submitButton = page.getByRole('button', { name: 'submit', exact: true });

    await expect(activity).toBeVisible();
    await expect(choiceOne).toBeVisible();
    await expect(choiceTwo).toBeVisible();

    await choiceOne.click();
    await choiceTwo.click();

    await expect(choiceOne).toBeChecked();
    await expect(choiceTwo).toBeChecked();

    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(activity).toHaveClass(/evaluated/);
    await expect(page.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(page.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. You selected the right answers.',
    );
    await expect(page.getByLabel('result')).toHaveCount(1);
  });

  test('student selecting only an incorrect answer sees incorrect feedback', async ({
    homeTask,
    page,
  }) => {
    await openStudentDeliveryPractice(homeTask, page, sections.negative, activityTitle);
    const activity = page.locator('.activity.cata-activity');
    const incorrectChoice = page
      .locator('.activity.cata-activity [role="checkbox"]')
      .filter({ hasText: 'Incorrect' })
      .first();
    const submitButton = page.getByRole('button', { name: 'submit', exact: true });

    await expect(activity).toBeVisible();
    await expect(incorrectChoice).toBeVisible();

    await incorrectChoice.click();

    await expect(incorrectChoice).toBeChecked();
    await expect(submitButton).toBeEnabled();
    await submitButton.click();

    await expect(activity).toHaveClass(/evaluated/);
    await expect(page.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(page.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );
    await expect(page.locator('.evaluation.feedback.correct')).toHaveCount(0);
  });
});
