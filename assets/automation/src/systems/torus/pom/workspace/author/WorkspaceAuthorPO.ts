import { expect, Page } from "@playwright/test";
import { AuthorDashboardPO } from "./AuthorDashboardPO";
import { AuthorSidebarCO } from "./AuthorSidebarCO";
import { OverviewProjectPO } from "./OverviewProjectPO";
import { PublishProjectPO } from "./PublishProjectPO";
import { NewCourseSetupPO } from "../instructor/NewCourseSetupPO";

export class WorkspaceAuthorPO {
  private page: Page;
  private authorDashboard: AuthorDashboardPO;
  private authorSidebar: AuthorSidebarCO;
  private overviewProject: OverviewProjectPO;
  private publishProject: PublishProjectPO;
  private newcoursesetup: NewCourseSetupPO;

  constructor(page: Page) {
    this.page = page;
    this.authorDashboard = new AuthorDashboardPO(this.page);
    this.authorSidebar = new AuthorSidebarCO(this.page);
    this.overviewProject = new OverviewProjectPO(this.page);
    this.publishProject = new PublishProjectPO(this.page);
    this.newcoursesetup = new NewCourseSetupPO(this.page);
  }

  getAuthorDashboard(): AuthorDashboardPO {
    return this.authorDashboard;
  }

  getAuthorSidebar(): AuthorSidebarCO {
    return this.authorSidebar;
  }

  getOverviewProject(): OverviewProjectPO {
    return this.overviewProject;
  }

  getPublishProject(): PublishProjectPO {
    return this.publishProject;
  }

  getNewCourseSetup(): NewCourseSetupPO {
    return this.newcoursesetup;
  }

  async verifyHeader(expectedHeader: string) {
    await expect(this.page.locator("h1")).toContainText(expectedHeader);
  }
}
