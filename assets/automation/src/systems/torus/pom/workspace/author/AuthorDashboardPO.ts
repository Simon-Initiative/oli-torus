import { Page, Locator } from '@playwright/test';
import { Utils } from '../../../../../core/Utils';

export class AuthorDashboardPO {
  private utils: Utils;
  private searchInput: Locator;

  private newProjectButton: Locator;
  private projectNameInput: Locator;
  private createButton: Locator;
  private projectLink: Locator;
  private createHeader: Locator;
  private projectRows: Locator;
  private tableRows: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(page);
    this.searchInput = this.page.locator('#text-search-input');
    this.createHeader = page.getByRole('cell', { name: 'Created', exact: true });
    this.projectRows = page.locator('table tbody tr');
    this.newProjectButton = this.page.locator('#button-new-project');
    this.projectNameInput = this.page.locator('#project_title');
    this.createButton = this.page.getByRole('button', { name: 'Create' });
    this.tableRows = this.page.locator('#projects-table table > tbody > tr');
  }

  async searchProject(name: string) {
    await this.searchInput.click();
    await this.utils.sleep(1);
    await this.searchInput.fill(name);
    await this.utils.sleep(1);
  }

  async clickNewProjectButton() {
    await this.utils.forceClick(this.newProjectButton, this.projectNameInput);
  }

  async sortByCreatedDescending() {
    await this.createHeader.click();
  }

  async getLastProjectName() {
    const rows = await this.tableRows.all();
    const lastRow = rows.at(-1);
    if (lastRow) {
      const nameLocator = lastRow.locator('td > div > a');
      return await nameLocator.innerText();
    } else return null;
  }

  // async getLastProjectName() {
  //   const firstRow = this.projectRows.first();
  //   const projectLink = firstRow.locator('td > div > a');
  //   await projectLink.click();
  // }

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
