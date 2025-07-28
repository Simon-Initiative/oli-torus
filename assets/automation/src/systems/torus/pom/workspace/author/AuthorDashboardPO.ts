import { Page, Locator } from '@playwright/test';
import { Utils } from '@core/Utils';

export class AuthorDashboardPO {
  private utils: Utils;
  private searchInput: Locator;
  private newProjectButton: Locator;
  private projectNameInput: Locator;
  private createButton: Locator;
  private createHeader: Locator;
  private tableRows: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(page);
    this.searchInput = this.page.locator('#text-search-input');
    this.createHeader = page.getByRole('cell', { name: 'Created', exact: true });
    this.newProjectButton = this.page.locator('#button-new-project');
    this.projectNameInput = this.page.locator('#project_title');
    this.createButton = this.page.getByRole('button', { name: 'Create' });
    this.tableRows = this.page.locator('#projects-table table > tbody > tr');
  }

  get table() {
    return {
      sortByCreatedDescending: async () => await this.createHeader.click(),

      getLastProjectName: async () => {
        const rows = await this.tableRows.all();
        const lastRow = rows.at(-1);
        if (lastRow) {
          const nameLocator = lastRow.locator('td > div > a');
          return await nameLocator.innerText();
        } else return null;
      },

      clickProjectLink: async (projectName: string) => {
        const projectLink = this.page.getByRole('link', { name: projectName });
        await projectLink.click();
      },
    };
  }

  get search() {
    return {
      fillSearchInput: async (name: string) => {
        await this.searchInput.click();
        await this.utils.sleep(1);
        await this.searchInput.fill(name);
        await this.utils.sleep(1);
      },
    };
  }

  get new() {
    return {
      clickNewProjectButton: async () =>
        await this.utils.forceClick(this.newProjectButton, this.projectNameInput),

      fillProjectName: async (name: string) => {
        await this.projectNameInput.click();
        await this.projectNameInput.fill(name);
      },

      clickCreateButton: async () => await this.createButton.click(),
    };
  }
}
