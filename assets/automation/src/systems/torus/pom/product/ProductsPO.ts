import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class ProductsPO {
  private readonly header: Locator;
  private readonly createInput: Locator;
  private readonly createButton: Locator;

  constructor(private readonly page: Page) {
    this.header = page.locator('#header_id');
    this.createInput = page.getByRole('textbox', { name: 'Create a new product with' });
    this.createButton = page.getByRole('button', { name: 'Create Product' });
  }

  async verifyHeader() {
    await Verifier.expectContainText(this.header, 'Products');
  }

  async createProduct(baseName: string) {
    const uniqueName = `${baseName} Product`;
    await this.createInput.click({ force: true });
    await this.createInput.fill(uniqueName);
    await this.createButton.click();

    return uniqueName;
  }

  async openProduct(productName: string) {
    const productLink = this.page.getByRole('link', { name: productName });
    await productLink.click();
  }
}
