import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import {
  configureStudentDeliveryRuntimeConfig,
  seedStudentDeliveryScenario,
  waitForMainLiveView,
} from '../student_delivery/support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './transfer-enrollment.scenario.yaml');
const transferMessages = {
  description:
    "This will transfer this student's enrollment, and all their current progress, to the selected course section. If this student is already enrolled in the selected course section, that progress will be lost.",
  emptySections: 'There are no other sections to transfer this student to.',
  emptyStudents: 'There are no other students to transfer this student to.',
  success: 'Enrollment successfully transferred',
} as const;

type SectionSlugs = {
  source: string;
  target: string;
  cancelSource: string;
  cancelTarget: string;
  overwriteSource: string;
  overwriteTarget: string;
  isolatedSource: string;
};

let sectionSlugs!: SectionSlugs;

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

test.beforeAll(async ({ seedScenario }) => {
  const { sections = {} } = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sectionSlugs = {
    source: sections.transfer_enrollment_source_section ?? '',
    target: sections.transfer_enrollment_target_section ?? '',
    cancelSource: sections.transfer_enrollment_cancel_source_section ?? '',
    cancelTarget: sections.transfer_enrollment_cancel_target_section ?? '',
    overwriteSource: sections.transfer_enrollment_overwrite_source_section ?? '',
    overwriteTarget: sections.transfer_enrollment_overwrite_target_section ?? '',
    isolatedSource: sections.isolated_transfer_enrollment_source_section ?? '',
  };

  expect(
    sectionSlugs.source,
    'Missing scenario output for transfer_enrollment_source_section',
  ).toBeTruthy();
  expect(
    sectionSlugs.target,
    'Missing scenario output for transfer_enrollment_target_section',
  ).toBeTruthy();
  expect(
    sectionSlugs.cancelSource,
    'Missing scenario output for transfer_enrollment_cancel_source_section',
  ).toBeTruthy();
  expect(
    sectionSlugs.cancelTarget,
    'Missing scenario output for transfer_enrollment_cancel_target_section',
  ).toBeTruthy();
  expect(
    sectionSlugs.overwriteSource,
    'Missing scenario output for transfer_enrollment_overwrite_source_section',
  ).toBeTruthy();
  expect(
    sectionSlugs.overwriteTarget,
    'Missing scenario output for transfer_enrollment_overwrite_target_section',
  ).toBeTruthy();
  expect(
    sectionSlugs.isolatedSource,
    'Missing scenario output for isolated_transfer_enrollment_source_section',
  ).toBeTruthy();
});

test.describe('enrollment transfer', () => {
  test('admin can transfer enrollment data between sections and preserve learner score', async ({
    homeTask,
    page,
  }) => {
    const { source, target } = sectionSlugs;

    await homeTask.login('administrator');

    // Baseline: the target student exists and still has no score before the transfer.
    await openStudentActionsFromInstructorStudents(page, target, 'Target, Transfer');
    await expectStudentMetric(page, 'course completion', '0%');
    await expectStudentMetric(page, 'average score', '-');

    // Open the source student actions and launch the transfer modal.
    await openTransferEnrollmentModal(page, source, 'Source, Transfer');

    // Pick the destination section and student, then confirm the transfer.
    await selectTransferModalRow(page, transferSectionTitle('Target'));
    await selectTransferModalRow(page, 'Transfer Target');

    await expect(page.getByRole('button', { name: 'Confirm', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();

    await expect(page.locator('#live_flash_container')).toContainText(transferMessages.success);

    // Verify both sections now reflect the expected post-transfer state.
    await findSectionStudentLink(page, target, 'Target, Transfer');
    await findSectionStudentLink(page, source, 'Source, Transfer');

    // Destination keeps the transferred score, source keeps the enrollment shell.
    await openStudentActionsFromInstructorStudents(page, target, 'Target, Transfer');
    await expectStudentMetric(page, 'course completion', '0%');
    await expectStudentMetric(page, 'average score', '100%');

    await openStudentActionsFromInstructorStudents(page, source, 'Source, Transfer');
    await expectStudentMetric(page, 'average score', '-');
  });

  test('admin overwrites existing target progress when transferring enrollment', async ({
    homeTask,
    page,
  }) => {
    const { overwriteSource, overwriteTarget } = sectionSlugs;

    await homeTask.login('administrator');

    await openStudentActionsFromInstructorStudents(
      page,
      overwriteTarget,
      'Overwrite Target, Transfer',
    );
    await expectStudentMetric(page, 'average score', '0%');

    await openTransferEnrollmentModal(
      page,
      overwriteSource,
      'Overwrite Source, Transfer',
    );
    await selectTransferModalRow(page, transferSectionTitle('Overwrite Target'));
    await selectTransferModalRow(page, 'Transfer Overwrite Target');
    await expect(page.locator('#transfer_enrollment_modal')).toContainText(
      'Transfer Overwrite Target',
    );

    await page.getByRole('button', { name: 'Confirm', exact: true }).click();
    await expect(page.locator('#live_flash_container')).toContainText(transferMessages.success);

    await openStudentActionsFromInstructorStudents(
      page,
      overwriteTarget,
      'Overwrite Target, Transfer',
    );
    await expectStudentMetric(page, 'average score', '100%');

    await openStudentActionsFromInstructorStudents(
      page,
      overwriteSource,
      'Overwrite Source, Transfer',
    );
    await expectStudentMetric(page, 'average score', '-');
  });

  test('admin can close transfer enrollment after making selections without changing learner data', async ({
    homeTask,
    page,
  }) => {
    const { cancelSource, cancelTarget } = sectionSlugs;

    await homeTask.login('administrator');

    await openStudentActionsFromInstructorStudents(
      page,
      cancelSource,
      'Cancel Source, Transfer',
    );
    await expectStudentMetric(page, 'average score', '100%');

    await openTransferEnrollmentModal(page, cancelSource, 'Cancel Source, Transfer');
    await selectTransferModalRow(page, transferSectionTitle('Cancel Target'));
    await selectTransferModalRow(page, 'Transfer Cancel Target');
    await expect(page.getByRole('button', { name: 'Confirm', exact: true })).toBeVisible();

    await page.locator('#transfer_enrollment_modal_backdrop button[phx-click="close"]').click();
    await expect(page.locator('#transfer_enrollment_modal_backdrop')).toHaveCount(0);
    await expect(page.getByText(transferMessages.success)).toHaveCount(0);

    await openStudentActionsFromInstructorStudents(
      page,
      cancelSource,
      'Cancel Source, Transfer',
    );
    await expectStudentMetric(page, 'average score', '100%');

    await openStudentActionsFromInstructorStudents(
      page,
      cancelTarget,
      'Cancel Target, Transfer',
    );
    await expectStudentMetric(page, 'average score', '-');
  });

  test('admin sees a no-sections message when no eligible transfer sections exist', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('administrator');
    await openTransferEnrollmentModal(page, sectionSlugs.isolatedSource, 'Solo, Transfer');

    await expect(page.locator('#transfer_enrollment_modal')).toContainText(
      transferMessages.emptySections,
    );
    await expect(page.getByRole('button', { name: 'Confirm', exact: true })).toHaveCount(0);
  });

  test('admin sees a no-students message when the selected section has no transfer candidates', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('administrator');
    await openTransferEnrollmentModal(page, sectionSlugs.source, 'Source, Transfer');

    await selectTransferModalRow(page, transferSectionTitle('Empty Target'));
    await expect(page.locator('#transfer_enrollment_modal')).toContainText(
      transferMessages.emptyStudents,
    );
    await expect(page.getByRole('button', { name: 'Confirm', exact: true })).toHaveCount(0);
  });

  test('non-admin instructor does not see the transfer enrollment action', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('instructor');
    await openStudentActionsFromInstructorStudents(page, sectionSlugs.source, 'Source, Transfer');

    await expect(page.locator('#transfer_enrollment')).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Transfer Enrollment', exact: true })).toHaveCount(
      0,
    );
  });
});

// Opens the actions page for a student and launches the transfer enrollment modal.
async function openTransferEnrollmentModal(page: Page, sectionSlug: string, studentName: string) {
  await openStudentActionsFromInstructorStudents(page, sectionSlug, studentName);
  await page.getByRole('button', { name: 'Transfer Enrollment', exact: true }).click();
  await expect(page.locator('#transfer_enrollment_modal_backdrop')).toBeVisible();
  await expect(page.locator('#transfer_enrollment_modal')).toContainText(transferMessages.description);
}

// Navigates from the instructor student list to the selected student's actions page.
async function openStudentActionsFromInstructorStudents(
  page: Page,
  sectionSlug: string,
  studentName: string,
) {
  const studentLink = await findSectionStudentLink(page, sectionSlug, studentName);
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

// Opens the instructor student list for a section and returns the student's dashboard link.
async function findSectionStudentLink(page: Page, sectionSlug: string, studentName: string) {
  await page.goto(`/sections/${sectionSlug}/instructor_dashboard/overview/students`, {
    waitUntil: 'load',
  });
  await expect(page.locator('#students_table')).toBeVisible();

  const studentLink = page
    .locator('#students_table')
    .getByRole('link', { name: studentName, exact: true })
    .first();
  await expect(studentLink).toBeVisible();

  return studentLink;
}

// Selects a row in the transfer modal's current table step by visible text.
async function selectTransferModalRow(page: Page, text: string) {
  const row = page.locator('#transfer_enrollment_modal tbody tr').filter({ hasText: text }).first();

  await expect(row).toBeVisible();
  await row.click();
}

// Asserts the displayed metric value inside the student details card.
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

// Builds the visible section title used in the transfer selection table.
const transferSectionTitle = (label: string) => `Enrollment Transfer Course ${runId} - ${label}`;
