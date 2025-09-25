import { expect, Page, Locator } from '@playwright/test';
import { InstructorDashboardPO } from './InstructorDashboardPO';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';

export class WorkspaceInstructorPO {
  constructor(private page: Page) {
  }

  get dashboard() {
    return new InstructorDashboardPO(this.page);
  }

  get newCourseSetup() {
    return new NewCourseSetupPO(this.page);
  }
}
