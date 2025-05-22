import { Page, Locator } from '@playwright/test';
import { Utils } from '../../../../../core/Utils';

export class AuthorDashboardPO {
  private page: Page;
  private utils: Utils;
  private searchInput: Locator;
  private tableRows: Locator;
  private newProjectButton: Locator;
  private projectNameInput: Locator;
  private createButton: Locator;
  private projectLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.utils = new Utils(page);
    this.searchInput = this.page.locator('#text-search-input');
    this.tableRows = this.page.locator('#projects-table table > tbody > tr');
    this.newProjectButton = this.page.locator('#button-new-project');
    this.projectNameInput = this.page.locator('#project_title');
    this.createButton = this.page.getByRole('button', { name: 'Create' });
  }

  async searchProject(name: string) {
    await this.searchInput.click();
    await this.utils.sleep(1);
    await this.searchInput.fill(name);
    await this.utils.sleep(1);
  }

  async clickNewProjectButton() {
    await this.utils.forceclick(this.newProjectButton, this.projectNameInput);
  }

  async getLastProjectName() {
    const rows = await this.tableRows.all();
    const lastRow = rows.at(-1);
    if (lastRow) {
      const nameLocator = lastRow.locator('td > div > a');
      return await nameLocator.innerText();
    } else return null;
  }

  async fillProjectName(name: string) {
    await this.projectNameInput.click();
    await this.projectNameInput.fill(name);
  }

  async clickCreateButton() {
    await this.createButton.click();
  }

  async clickProjectLink(projectName: string) {
    this.projectLink = this.page.getByRole('link', {
      name: projectName,
    });
    await this.projectLink.click();
  }
}
