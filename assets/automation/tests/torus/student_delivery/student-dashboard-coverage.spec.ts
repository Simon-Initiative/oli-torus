import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './student-dashboard-coverage.scenario.yaml');
const sectionTitle = `MER-5489 Student Dashboard Coverage ${runId}`;

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

test.describe('student dashboard, assignments, and schedule coverage', () => {
  test.beforeEach(async ({ homeTask }) => {
    await homeTask.login('student');
  });

  test('student dashboard lets the student find and open the course', async ({
    page,
    studentTask,
  }) => {
    await expect(page.getByRole('heading', { name: 'Courses available' })).toBeVisible();
    await studentTask.searchProject(sectionTitle);
    await expect(page.locator('#home-assignments')).toBeVisible();
  });

  test('assignments view loads for the course', async ({ page, studentTask }) => {
    await studentTask.searchProject(sectionTitle);

    await page.goto(assignmentsPath(sectionSlug), { waitUntil: 'load' });
    await expect(page).toHaveURL(assignmentsPath(sectionSlug));
    await expect(page.getByRole('heading', { name: 'Assignments' })).toBeVisible();
  });

  test('schedule view loads for the course', async ({ page, studentTask }) => {
    await studentTask.searchProject(sectionTitle);

    await page.goto(schedulePath(sectionSlug), { waitUntil: 'load' });
    await expect(page).toHaveURL(schedulePath(sectionSlug));
    await expect(page.getByRole('heading', { name: 'Course Schedule' })).toBeVisible();
    await expect(page.locator('#schedule-view')).toBeVisible();
  });
});

function assignmentsPath(sectionSlug: string) {
  return `/sections/${sectionSlug}/assignments?sidebar_expanded=true`;
}

function schedulePath(sectionSlug: string) {
  return `/sections/${sectionSlug}/student_schedule?sidebar_expanded=true`;
}
