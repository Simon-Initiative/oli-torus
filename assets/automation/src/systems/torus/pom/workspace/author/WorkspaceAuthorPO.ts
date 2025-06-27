import { expect, Page, Locator } from '@playwright/test';
import { AuthorDashboardPO } from './AuthorDashboardPO';
import { SidebarCO } from '@pom/component/SidebarCO';
import { OverviewProjectPO } from '@pom/project/OverviewProjectPO';
import { PublishProjectPO } from '@pom/project/PublishProjectPO';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';
import { CurriculumPO } from '@pom/project/CurriculumPO';

export class WorkspaceAuthorPO {
  private readonly header: Locator;

  constructor(private page: Page) {
    this.header = this.page.locator('h1');
  }

  get dashboard() {
    return new AuthorDashboardPO(this.page);
  }

  get sidebar() {
    return new SidebarCO(this.page);
  }

  get overviewProject() {
    return new OverviewProjectPO(this.page);
  }

  get publishProject() {
    return new PublishProjectPO(this.page);
  }

  get newCourseSetup() {
    return new NewCourseSetupPO(this.page);
  }

  get curriculum() {
    return new CurriculumPO(this.page);
  }

  async verifyHeader(expectedHeader: string) {
    await expect(this.header).toContainText(expectedHeader);
  }
}
