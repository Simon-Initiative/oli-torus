import { expect, Page } from "@playwright/test";
import { InstructorDashboardPO } from "./InstructorDashboardPO";
import { NewCourseSetupPO } from "../../course/NewCourseSetupPO";

export class WorkspaceInstructorPO {
  private page: Page;
  private dashboard: InstructorDashboardPO;
  private newCourseSetup: NewCourseSetupPO;

  constructor(page: Page) {
    this.page = page;
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
    await expect(this.page.locator("h1")).toContainText(expectedHeader);
  }
}
