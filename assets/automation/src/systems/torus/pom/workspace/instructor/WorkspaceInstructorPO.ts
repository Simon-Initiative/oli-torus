import { expect, Page, Locator } from '@playwright/test';
import { InstructorDashboardPO } from './InstructorDashboardPO';
import { NewCourseSetupPO } from '../../course/NewCourseSetupPO';

export class WorkspaceInstructorPO {
  private header: Locator;
  private dashboard: InstructorDashboardPO;
  private newCourseSetup: NewCourseSetupPO;

  constructor(private page: Page) {
    this.header = this.page.locator('h1');
    this.dashboard = new InstructorDashboardPO(page);
    this.newCourseSetup = new NewCourseSetupPO(page);
  }

  getDashboard(): InstructorDashboardPO {
    return this.dashboard;
  }

  getNewCourseSetup(): NewCourseSetupPO {
    return this.newCourseSetup;
  }

  async verifyrHeader(expectedHeader: string) {
    await expect(this.header).toContainText(expectedHeader);
  }
}
