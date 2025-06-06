import { expect, Page, Locator } from '@playwright/test';
import { AuthorDashboardPO } from './AuthorDashboardPO';
import { AuthorSidebarCO } from './AuthorSidebarCO';
import { OverviewProjectPO } from '../../project/OverviewProjectPO';
import { PublishProjectPO } from '../../project/PublishProjectPO';
import { NewCourseSetupPO } from '../../course/NewCourseSetupPO';

export class WorkspaceAuthorPO {
  private header: Locator;
  private dashboard: AuthorDashboardPO;
  private sidebar: AuthorSidebarCO;
  private overviewProject: OverviewProjectPO;
  private publishProject: PublishProjectPO;
  private newCourseSetup: NewCourseSetupPO;

  constructor(private page: Page) {
    this.header = this.page.locator('h1');
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
    await expect(this.header).toContainText(expectedHeader);
  }
}
