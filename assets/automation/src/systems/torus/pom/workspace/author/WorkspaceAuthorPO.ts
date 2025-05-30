import { expect, Page } from "@playwright/test";
import { AuthorDashboardPO } from "./AuthorDashboardPO";
import { AuthorSidebarCO } from "./AuthorSidebarCO";
import { OverviewProjectPO } from "../../project/OverviewProjectPO";
import { PublishProjectPO } from "../../project/PublishProjectPO";
import { NewCourseSetupPO } from "../../course/NewCourseSetupPO";

export class WorkspaceAuthorPO {
  private page: Page;
  private dashboard: AuthorDashboardPO;
  private sidebar: AuthorSidebarCO;
  private overviewProject: OverviewProjectPO;
  private publishProject: PublishProjectPO;
  private newCourseSetup: NewCourseSetupPO;

  constructor(page: Page) {
    this.page = page;
    this.dashboard = new AuthorDashboardPO(this.page);
    this.sidebar = new AuthorSidebarCO(this.page);
    this.overviewProject = new OverviewProjectPO(this.page);
    this.publishProject = new PublishProjectPO(this.page);
    this.newCourseSetup = new NewCourseSetupPO(this.page);
  }

  getDashboard(): AuthorDashboardPO {
    return this.dashboard;
  }

  getSidebar(): AuthorSidebarCO {
    return this.sidebar;
  }

  getOverviewProject(): OverviewProjectPO {
    return this.overviewProject;
  }

  getPublishProject(): PublishProjectPO {
    return this.publishProject;
  }

  getNewCourseSetup(): NewCourseSetupPO {
    return this.newCourseSetup;
  }

  async verifyHeader(expectedHeader: string) {
    await expect(this.page.locator("h1")).toContainText(expectedHeader);
  }
}
