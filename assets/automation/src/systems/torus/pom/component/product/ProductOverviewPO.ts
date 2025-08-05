import { expect, Locator, Page } from '@playwright/test';

export class ProductOverviewPO {
  private header: Locator;
  private titleInput: Locator;

  constructor(private page: Page) {
    this.header = page.locator('#header_id');
    this.titleInput = page.getByRole('textbox', { name: 'Title', exact: true });
  }

  async verifyHeader() {
    await expect(this.header).toContainText('Product Overview');
  }

  async verifyProductTitle(expectedTitle: string) {
    await expect(this.titleInput).toHaveValue(expectedTitle);
  }
}
