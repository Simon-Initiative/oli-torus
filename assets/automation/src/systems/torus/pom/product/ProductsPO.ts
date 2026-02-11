import { Table } from '@core/Table';
import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class ProductsPO {
  private readonly createInput: Locator;
  private readonly createButton: Locator;
  private readonly contentCenter: Locator;

  constructor(private readonly page: Page) {
    this.createInput = page.getByRole('textbox', { name: 'Create a new product with' });
    this.createButton = page.getByRole('button', { name: 'Create Product' });
    this.contentCenter = page.locator('#content > div.container.mx-auto.p-8');
  }

  async waitingToBeCentered() {
    await Waiter.waitFor(this.contentCenter, 'visible');
  }

  async createProduct(baseName: string) {
    const productName = `${baseName} Product`;
    await this.createInput.click({ force: true });
    await this.createInput.fill(productName);
    await this.createButton.click();
    await Waiter.waitFor(this.page.getByRole('link', { name: productName }), 'visible');

    const table = new Table(this.page);
    const cell = await table.getCellLocator(1, 1);
    const productId = (await cell.locator('span').textContent()).replace('ID: ', '');

    return { productName, productId };
  }

  async openProduct(productName: string) {
    const productLink = this.page.getByRole('link', { name: productName });
    await productLink.click();
  }
}
