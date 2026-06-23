import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import path from 'node:path';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

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
    const { activity, choiceOne, choiceTwo, submitButton } = await openCataPractice(
      homeTask,
      page,
      sections.positive,
    );

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
    const { activity, submitButton } = await openCataPractice(homeTask, page, sections.negative);
    const incorrectChoice = page
      .locator('.activity.cata-activity [role="checkbox"]')
      .filter({ hasText: 'Incorrect' })
      .first();

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

function learnPath(sectionSlug: string) {
  return `/sections/${sectionSlug}/learn?sidebar_expanded=true&selected_view=outline`;
}

async function gotoPath(page: Page, pathName: string) {
  await page.goto(pathName, { waitUntil: 'load' });
}

async function openCataPractice(
  homeTask: { login(role: 'student'): Promise<void> },
  page: Page,
  sectionSlug: string,
) {
  const studentCourse = new StudentCoursePO(page);

  await homeTask.login('student');
  await gotoPath(page, learnPath(sectionSlug));
  await studentCourse.goToCourseIfPrompted();

  const practiceButton = page.getByText('Practice', { exact: true }).first();
  await expect(practiceButton).toBeVisible();
  await practiceButton.click();

  await expect(page.getByText(activityTitle).first()).toBeVisible();

  return {
    activity: page.locator('.activity.cata-activity'),
    choiceOne: page.getByRole('checkbox', { name: 'choice 1', exact: true }),
    choiceTwo: page.getByRole('checkbox', { name: 'choice 2', exact: true }),
    submitButton: page.getByRole('button', { name: 'submit', exact: true }),
  };
}
