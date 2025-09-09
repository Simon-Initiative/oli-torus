import { expect, Locator, Page } from '@playwright/test';

export class ProductsPO {
  private header: Locator;
  private createInput: Locator;
  private createButton: Locator;
  private archivedCheckbox: Locator;

  constructor(private page: Page) {
    this.header = page.locator('#header_id');
    this.createInput = page.getByRole('textbox', { name: 'Create a new product with' });
    this.createButton = page.getByRole('button', { name: 'Create Product' });
    this.archivedCheckbox = page.getByRole('checkbox');
  }

  async verifyHeader() {
    await expect(this.header).toContainText('Products');
  }

  async createProduct(productName: string) {
    await this.createInput.click();
    await this.createInput.fill(productName);
    await this.createButton.click();
  }

  // TODO: en realidad esto no lo usamos
  // async toggleArchivedView(enabled: boolean) {
  //   if ((await this.archivedCheckbox.isChecked()) !== enabled) {
  //     await this.archivedCheckbox.setChecked(enabled);
  //   }
  // }

  async openProduct(productName: string) {
    await this.page.getByRole('link', { name: productName }).click();
  }
}
