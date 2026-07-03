import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from '../student_delivery/support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './transfer-enrollment.scenario.yaml');
const transferEnrollmentMessage =
  "This will transfer this student's enrollment, and all their current progress, to the selected course section.";

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'transfer-enrollment-student',
    welcomeTitle: 'Hi, Transfer',
    name: 'Transfer',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'transfer-enrollment-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'transfer-enrollment-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'transfer-enrollment-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sourceSectionSlug = '';
let targetSectionSlug = '';

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sourceSectionSlug = outputs.sections?.transfer_enrollment_source_section ?? '';
  targetSectionSlug = outputs.sections?.transfer_enrollment_target_section ?? '';

  expect(sourceSectionSlug).toBeTruthy();
  expect(targetSectionSlug).toBeTruthy();
});

test.describe('enrollment transfer', () => {
  test('admin can transfer enrollment data between sections and preserve learner score', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('administrator');

    // Baseline: the target student exists and still has no score before the transfer.
    await openStudentActionsFromInstructorStudents(page, targetSectionSlug, 'Target, Transfer');
    await expectStudentMetric(page, 'course completion', '0%');

    // Open the source student actions and launch the transfer modal.
    await openStudentActionsFromInstructorStudents(page, sourceSectionSlug, 'Source, Transfer');
    await page.getByRole('button', { name: 'Transfer Enrollment', exact: true }).click();
    await expect(page.locator('#transfer_enrollment_modal_backdrop')).toBeVisible();
    await expect(page.locator('#transfer_enrollment_modal')).toContainText(transferEnrollmentMessage);

    // Pick the destination section and student, then confirm the transfer.
    await selectTransferModalRow(page, `Enrollment Transfer Course ${runId} - Target`);
    await selectTransferModalRow(page, 'Transfer Target');

    await expect(page.getByRole('button', { name: 'Confirm', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();

    await expect(page.locator('#live_flash_container')).toContainText(
      'Enrollment successfully transfered',
    );

    // Verify both sections now reflect the expected post-transfer state.
    await expectStudentListedInInstructorStudents(page, targetSectionSlug, 'Target, Transfer');
    await expectStudentListedInInstructorStudents(page, sourceSectionSlug, 'Source, Transfer');

    // Destination keeps the transferred score, source keeps the enrollment shell.
    await openStudentActionsFromInstructorStudents(page, targetSectionSlug, 'Target, Transfer');
    await expectStudentMetric(page, 'course completion', '0%');
    await expectStudentMetric(page, 'average score', '100%');

    await openStudentActionsFromInstructorStudents(page, sourceSectionSlug, 'Source, Transfer');
    await expectStudentMetric(page, 'average score', '-');
  });
});

async function openStudentActionsFromInstructorStudents(
  page: Page,
  sectionSlug: string,
  studentName: string,
) {
  await page.goto(`/sections/${sectionSlug}/instructor_dashboard/overview/students`, {
    waitUntil: 'load',
  });
  await expect(page.locator('#students_table')).toBeVisible();

  const studentLink = page
    .locator('#students_table')
    .getByRole('link', { name: studentName, exact: true })
    .first();
  await expect(studentLink).toBeVisible();

  const href = await studentLink.getAttribute('href');

  if (!href) {
    throw new Error(`Could not read student dashboard link for ${studentName}`);
  }

  const studentActionsUrl = new URL(href, page.url());
  studentActionsUrl.pathname = studentActionsUrl.pathname.replace(/\/content$/, '/actions');

  await page.goto(studentActionsUrl.toString(), { waitUntil: 'load' });
  await waitForMainLiveView(page);
  await expect(page.locator('#student_actions')).toBeVisible();
}

async function selectTransferModalRow(page: Page, text: string) {
  const row = page.locator('#transfer_enrollment_modal tbody tr').filter({ hasText: text }).first();

  await expect(row).toBeVisible();
  await row.click();
}

async function expectStudentListedInInstructorStudents(
  page: Page,
  sectionSlug: string,
  studentName: string,
) {
  // This list is the simplest way to confirm the enrollment still exists in the section.
  await page.goto(`/sections/${sectionSlug}/instructor_dashboard/overview/students`, {
    waitUntil: 'load',
  });
  await expect(page.locator('#students_table')).toBeVisible();

  const studentLink = page
    .locator('#students_table')
    .getByRole('link', { name: studentName, exact: true })
    .first();

  await expect(studentLink).toHaveCount(1);
}

async function expectStudentMetric(
  page: Page,
  label: 'average score' | 'course completion',
  value: string,
) {
  const metric = page
    .locator('#student_details_card h4')
    .filter({ hasText: label })
    .locator('xpath=following-sibling::span');

  await expect(metric).toContainText(value);
}

async function waitForMainLiveView(page: Page) {
  await page.waitForFunction(
    () => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'),
    undefined,
    { timeout: 15_000 },
  );
}
