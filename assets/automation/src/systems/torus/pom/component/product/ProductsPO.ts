import { expect, Locator, Page } from '@playwright/test';

export class ProductsPO {
  private readonly header: Locator;
  private readonly createInput: Locator;
  private readonly createButton: Locator;

  constructor(private page: Page) {
    this.header = page.locator('#header_id');
    this.createInput = page.getByRole('textbox', { name: 'Create a new product with' });
    this.createButton = page.getByRole('button', { name: 'Create Product' });
  }

  async verifyHeader() {
    await expect(this.header).toContainText('Products');
  }

  async createProduct(productName: string) {
    await this.createInput.click();
    await this.createInput.fill(productName);
    await this.createButton.click();
  }

  async openProduct(productName: string) {
    await this.page.getByRole('link', { name: productName }).click();
  }
}
