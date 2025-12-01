import { Page, Locator } from '@playwright/test';
import { Utils } from '@core/Utils';
import { Table } from '@core/Table';
import { Verifier } from '@core/verify/Verifier';

export class AuthorDashboardPO {
  private readonly utils: Utils;
  private readonly searchInput: Locator;
  private readonly newProjectButton: Locator;
  private readonly projectNameInput: Locator;
  private readonly createButton: Locator;
  private readonly titleHeader: Locator;

  constructor(private readonly page: Page) {
    this.utils = new Utils(page);
    this.searchInput = page.locator('#text-search-input');
    this.newProjectButton = page.locator('#button-new-project');
    this.projectNameInput = page.locator('#project_title');
    this.titleHeader = page.getByRole('cell', { name: 'Title', exact: true });
    this.createButton = page.getByRole('button', { name: 'Create' });
  }

  async getAllRowsTable() {
    return await new Table(this.page).getDataAllRows();
  }

  async getFirstRowTable() {
    const rows = await this.getAllRowsTable();
    return rows[0];
  }

  async clickProjectLink(projectName: string) {
    const projectLink = this.page.getByRole('link', { name: projectName });
    await projectLink.click();
  }

  async sortByTitleDescending() {
    if (await this.titleHeader.isVisible()) {
      await this.titleHeader.click();
      await new Utils(this.page).sleep(2);
    }
  }

  async searchProject(name: string) {
    await this.utils.writeWithDelay(this.searchInput, name);
    await Verifier.expectNotContainClass(this.searchInput, 'phx-hook-loading');
  }

  async clickNewProjectButton() {
    await this.utils.forceClick(this.newProjectButton, this.projectNameInput);
  }
  async fillProjectName(name: string) {
    await this.projectNameInput.click();
    await this.projectNameInput.fill(name);
  }

  async clickCreateButton() {
    await this.createButton.click();
  }
}
