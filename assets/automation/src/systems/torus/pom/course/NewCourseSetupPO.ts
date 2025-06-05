import { expect, Locator, Page } from '@playwright/test';
import { Utils } from '../../../../core/Utils';

export class NewCourseSetupPO {
  private page: Page;
  private utils: Utils;
  private searchInput: Locator;
  private searchButton: Locator;
  private resultsSummary: Locator;
  private stepperContent: Locator;

  constructor(page: Page) {
    this.page = page;
    this.utils = new Utils(this.page);
    this.searchInput = this.page.getByRole('textbox', { name: 'Search...' });
    this.searchButton = this.page.getByRole('button', { name: 'Search' });
    this.resultsSummary = this.page.getByText('Results filtered on "');
    this.stepperContent = this.page.locator('#stepper_content');
  }

  async searchProject(name: string) {
    await this.searchInput.click();
    await this.searchInput.fill(name);
    await this.utils.sleep(2);
    await this.searchButton.click();
  }

  async verifySearchResult(name: string) {
    await expect(this.resultsSummary).toContainText(`Results filtered on "${name}"`);
    await expect(this.stepperContent).toContainText('Showing all results (1 total)');
  }

  async verifyTextStepperContent(str: string) {
    await expect(this.stepperContent).toContainText(str);
  }
}
