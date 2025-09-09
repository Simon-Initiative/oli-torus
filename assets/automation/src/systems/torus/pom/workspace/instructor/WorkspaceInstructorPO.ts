import { expect, Page, Locator } from '@playwright/test';
import { InstructorDashboardPO } from './InstructorDashboardPO';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';

export class WorkspaceInstructorPO {
  private header: Locator;

  constructor(private page: Page) {
    this.header = this.page.getByRole('heading');
  }

  get dashboard() {
    return new InstructorDashboardPO(this.page);
  }

  get newCourseSetup() {
    return new NewCourseSetupPO(this.page);
  }

  async verifyHeader(expectedHeader: string) {
    await expect(this.header).toContainText(expectedHeader);
  }
}
