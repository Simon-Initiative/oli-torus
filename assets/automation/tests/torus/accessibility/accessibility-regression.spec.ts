import path from 'node:path';
import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import {
  expectKeyboardFocus,
  scanPageAccessibility,
  setAccessibilityTheme,
} from '@core/accessibility';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import {
  configureStudentDeliveryRuntimeConfig,
  seedStudentDeliveryScenario,
} from '../student_delivery/support';

const runId = `-${Date.now()}`;
const sectionTitle = `MER-5489 Student Dashboard Coverage ${runId}`;
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
let projectSlug = '';

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);
  sectionSlug = outputs.sections?.student_dashboard_coverage_section ?? '';
  projectSlug = outputs.projects?.student_dashboard_coverage_project ?? '';
  expect(sectionSlug).toBeTruthy();
  expect(projectSlug).toBeTruthy();
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
    studentTask,
  }) => {
    await homeTask.login('student');
    await studentTask.searchProject(sectionTitle);
    await page.goto(learnPath(), { waitUntil: 'domcontentloaded' });
    const studentCourse = new StudentCoursePO(page);
    await studentCourse.goToCourseIfPrompted();
    await expect(page.locator('#student_learn')).toBeVisible();
    await scanPageAccessibility(page, 'course outline');
    await expectKeyboardFocus(page, 'a, button, input');

    await studentCourse.openPage('Coverage Page');
    await scanPageAccessibility(page, 'coverage page');

    // Notes are only available when collaboration spaces are enabled for the section.
    const notesToggle = page.getByRole('button', { name: 'Toggle Notes panel' });
    if (await notesToggle.isVisible().catch(() => false)) {
      await notesToggle.click();
      await expect(page.getByRole('complementary', { name: 'Notes Panel' })).toBeVisible();
      await scanPageAccessibility(page, 'notes');
    }
  });

  test('scored activity has no automated accessibility violations', async ({
    page,
    homeTask,
    studentTask,
  }) => {
    await homeTask.login('student');
    await studentTask.searchProject(sectionTitle);
    await page.goto(learnPath(), { waitUntil: 'domcontentloaded' });
    const studentCourse = new StudentCoursePO(page);
    await studentCourse.goToCourseIfPrompted();
    await expect(page.locator('#student_learn')).toBeVisible();
    await expect(page.locator('[id^="outline_rows-"] button').first()).toBeVisible();
    await studentCourse.openPage('Scored Activity');
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
    await page.goto(`/workspaces/course_author/${projectSlug}/curriculum`, {
      waitUntil: 'domcontentloaded',
    });
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
