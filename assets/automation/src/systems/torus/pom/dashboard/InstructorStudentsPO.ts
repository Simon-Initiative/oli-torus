import { expect, Locator, Page } from '@playwright/test';

export class InstructorStudentsPO {
  private readonly studentsTable: Locator;

  constructor(private readonly page: Page) {
    this.studentsTable = page.locator('#students_table');
  }

  /** Opens the instructor Students view for a section. */
  async open(sectionSlug: string) {
    await this.page.goto(`/sections/${sectionSlug}/instructor_dashboard/overview/students`, {
      waitUntil: 'load',
    });
    await this.waitForMainLiveView();
    await expect(this.studentsTable).toBeVisible();
  }

  /** Filters the Students table by active or suspended enrollment status. */
  async selectEnrollmentFilter(filter: 'Enrolled' | 'Suspended') {
    await this.page.locator('#filter-select-selected-options-container').click();
    await this.page
      .locator('#filter-select-options-container')
      .getByRole('button', { name: filter, exact: true })
      .click();
    await expect(this.page.locator('#filter-select-selected-options-container')).toContainText(
      filter,
    );
  }

  /** Verifies that a student appears in the current filtered table. */
  async expectStudentVisible(studentName: string) {
    await expect(this.studentLink(studentName)).toBeVisible();
  }

  /** Verifies that a student does not appear in the current filtered table. */
  async expectStudentNotVisible(studentName: string) {
    await expect(this.studentLink(studentName)).toHaveCount(0);
  }

  /** Opens the Actions tab for the named student in the current table. */
  async openStudentActions(studentName: string) {
    await this.studentLink(studentName).click();
    await this.waitForMainLiveView();
    await this.page.getByRole('link', { name: 'Actions', exact: true }).click();
    await this.waitForMainLiveView();
    await expect(this.page.locator('#student_actions')).toBeVisible();
  }

  /** Unenrolls the selected student through the confirmation modal. */
  async unenroll(studentName: string, sectionTitle: string) {
    await this.page.getByRole('button', { name: 'Unenroll', exact: true }).click();

    const modal = this.page.locator('#unenroll_user_modal-container');
    await expect(modal).toBeVisible();
    await expect(modal).toContainText(
      `Are you sure you want to unenroll ${studentName} from the course ${sectionTitle}`,
    );
    await Promise.all([
      this.page.waitForURL((url) => url.pathname.endsWith('/manage')),
      modal.getByRole('button', { name: 'Confirm', exact: true }).click(),
    ]);
  }

  /** Verifies that the suspended enrollment offers re-enrollment, not unenrollment. */
  async expectReEnrollAvailable() {
    await expect(this.page.getByRole('button', { name: 'Re-enroll', exact: true })).toBeVisible();
    await expect(this.page.getByRole('button', { name: 'Unenroll', exact: true })).toHaveCount(0);
  }

  /** Re-enrolls the selected student through the confirmation modal. */
  async reEnroll(studentName: string, sectionTitle: string) {
    await this.page.getByRole('button', { name: 'Re-enroll', exact: true }).click();

    const modal = this.page.locator('#re_enroll_user_modal-container');
    await expect(modal).toBeVisible();
    await expect(modal).toContainText(
      `Are you sure you want to re-enroll ${studentName} in the course ${sectionTitle}`,
    );
    await Promise.all([
      this.page.waitForURL((url) => url.pathname.endsWith('/manage')),
      modal.getByRole('button', { name: 'Confirm', exact: true }).click(),
    ]);
  }

  private studentLink(studentName: string) {
    return this.studentsTable.getByRole('link', { name: studentName, exact: true }).first();
  }

  private async waitForMainLiveView() {
    await this.page.waitForFunction(
      () => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'),
      undefined,
      { timeout: 15_000 },
    );
  }
}
