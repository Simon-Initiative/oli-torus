import path from 'node:path';
import { test } from '@fixture/my-fixture';
import {
  expectKeyboardFocus,
  scanPageAccessibility,
  setAccessibilityTheme,
} from '@core/accessibility';
import {
  configureStudentDeliveryRuntimeConfig,
  seedStudentDeliveryScenario,
} from '../student_delivery/support';
import { expect } from '@playwright/test';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(
  __dirname,
  '../student_delivery/student-dashboard-coverage.scenario.yaml',
);

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'student-dashboard-coverage-student',
    welcomeTitle: 'Hi, Coverage',
    name: 'Coverage',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'student-dashboard-coverage-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'student-dashboard-coverage-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'student-dashboard-coverage-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sectionSlug = '';

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);
  sectionSlug = outputs.sections?.student_dashboard_coverage_section ?? '';
  expect(sectionSlug).toBeTruthy();
});

test.describe('accessibility regression coverage @pr @accessibility', () => {
  test('student home has no automated accessibility violations', async ({ page, homeTask }) => {
    await homeTask.login('student');
    await scanPageAccessibility(page, 'student home');
    await expectKeyboardFocus(page, 'a, button, input');
  });

  test('course outline and notes have no automated accessibility violations', async ({
    page,
    homeTask,
  }) => {
    await homeTask.login('student');
    await page.goto(learnPath(), { waitUntil: 'domcontentloaded' });
    await scanPageAccessibility(page, 'course outline');
    await expectKeyboardFocus(page, 'a, button, input');

    const notesLink = page.getByRole('link', { name: 'Notes' });
    await expect(notesLink).toBeVisible();
    await notesLink.click();
    await scanPageAccessibility(page, 'notes');
  });

  test('scored activity has no automated accessibility violations', async ({ page, homeTask }) => {
    await homeTask.login('student');
    await page.goto(learnPath(), { waitUntil: 'domcontentloaded' });
    const scoredActivity = page.getByText('Scored Activity', { exact: true }).first();
    await expect(scoredActivity).toBeVisible();
    await scoredActivity.click();
    await scanPageAccessibility(page, 'scored activity');
    await expectKeyboardFocus(page, 'a, button, input');
  });

  test('schedule has light and dark theme accessibility coverage', async ({ page, homeTask }) => {
    await homeTask.login('student');
    await page.goto(schedulePath(), { waitUntil: 'domcontentloaded' });
    await scanPageAccessibility(page, 'schedule', { theme: 'light' });
    await setAccessibilityTheme(page, 'dark');
    await scanPageAccessibility(page, 'schedule', { theme: 'dark' });
    await expectKeyboardFocus(page, 'a, button, input');
  });

  test('account settings has no automated accessibility violations', async ({ page, homeTask }) => {
    await homeTask.login('student');
    await page.goto('/users/settings', { waitUntil: 'domcontentloaded' });
    await scanPageAccessibility(page, 'account settings');
    await expectKeyboardFocus(page, 'a, button, input');
  });

  test('authoring curriculum has no automated accessibility violations', async ({
    page,
    homeTask,
  }) => {
    await homeTask.login('author');
    await homeTask.enterToCurriculum();
    await scanPageAccessibility(page, 'authoring curriculum');
    await expectKeyboardFocus(page, 'a, button, input');
  });
});

function learnPath() {
  return `/sections/${sectionSlug}/learn?sidebar_expanded=true&selected_view=outline`;
}

function schedulePath() {
  return `/sections/${sectionSlug}/student_schedule?sidebar_expanded=true`;
}
