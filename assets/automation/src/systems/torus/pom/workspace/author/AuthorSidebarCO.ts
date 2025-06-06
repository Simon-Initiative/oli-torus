import { Locator, Page } from '@playwright/test';

export class AuthorSidebarCO {
  private publishMenuButton: Locator;
  private publishLink: Locator;
  private createButton: Locator;
  private curriculumLink: Locator;

  constructor(private page: Page) {
    this.publishMenuButton = this.page.getByRole('button', { name: 'Publish' });
    this.publishLink = this.page.getByRole('link', { name: 'Publish' });
    this.createButton = this.page.getByRole('button', { name: 'Create' });
    this.curriculumLink = this.page.getByRole('link', { name: 'Curriculum' });
  }

  async clickPublishProject() {
    await this.publishMenuButton.click();
  }

  async clickPublishLink() {
    await this.publishLink.click();
  }

  async clickCreateButton() {
    await this.createButton.click();
  }

  async clickCurriculumLink() {
    await this.curriculumLink.click();
  }
}
