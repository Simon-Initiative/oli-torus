import { Table } from '@core/Table';
import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class ProductsPO {
  private readonly createInput: Locator;
  private readonly createButton: Locator;
  private readonly contentCenter: Locator;
  private readonly newTemplateButton: Locator;
  private readonly templateModal: Locator;
  private readonly templateForm: Locator;
  private readonly templateTitleInput: Locator;
  private readonly templateCreateButton: Locator;
  private readonly titleInput: Locator;

  constructor(private readonly page: Page) {
    this.createInput = page.getByRole('textbox', { name: 'Create a new product with' });
    this.createButton = page.getByRole('button', { name: 'Create Product' });
    this.contentCenter = page.getByRole('heading', { name: 'Course Section Templates' });
    this.newTemplateButton = page.locator('#button-new-template');
    this.templateModal = page.locator('#create_template_modal').last();
    this.templateForm = page.locator('#create_template_form').last();
    this.templateTitleInput = this.templateForm.locator(
      'input[name="create_product_form[product_title]"]',
    );
    this.templateCreateButton = this.templateForm.getByRole('button', { name: 'Create' });
    this.titleInput = page.getByRole('textbox', { name: 'Title', exact: true });
  }

  async waitingToBeCentered() {
    await Waiter.waitFor(this.contentCenter, 'visible');
  }

  async createProduct(baseName: string) {
    const productName = `${baseName} Product`;

    if (await this.newTemplateButton.isVisible().catch(() => false)) {
      await this.openCreateTemplateForm();
      await this.templateTitleInput.fill(productName);
      await this.templateCreateButton.click();
      await this.page.waitForURL('**/products/**', { timeout: 15000 });
      await Waiter.waitFor(this.titleInput, 'visible');

      return { productName, productId: '' };
    }

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
    if (await this.titleInput.isVisible().catch(() => false)) {
      return;
    }

    const productLink = this.page.getByRole('link', { name: productName });
    await productLink.click();
  }

  private async openCreateTemplateForm() {
    await this.waitForLiveViewConnection();

    for (let attempt = 0; attempt < 3; attempt += 1) {
      await Waiter.waitFor(this.newTemplateButton, 'visible', 10000);
      await this.newTemplateButton.click();

      const opened = await this.templateTitleInput
        .waitFor({ state: 'visible', timeout: 5000 })
        .then(() => true)
        .catch(() => false);

      if (opened) return;

      await this.page.waitForTimeout(500);
    }

    await Waiter.waitFor(this.templateModal, 'visible', 10000);
    await Waiter.waitFor(this.templateTitleInput, 'visible', 10000);
  }

  private async waitForLiveViewConnection() {
    await this.page
      .waitForFunction(
        () => {
          const liveSocket = window.liveSocket;
          return liveSocket == null || liveSocket.isConnected();
        },
        undefined,
        { timeout: 5000 },
      )
      .catch(() => undefined);
  }
}
