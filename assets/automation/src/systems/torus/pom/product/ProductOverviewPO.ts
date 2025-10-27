import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class ProductOverviewPO {
  private readonly header: Locator;
  private readonly titleInput: Locator;
  private readonly toolbar: Locator;

  constructor(page: Page) {
    this.header = page.locator('#header_id');
    this.titleInput = page.getByRole('textbox', { name: 'Title', exact: true });
    this.toolbar = page.locator('.toolbar_nGbXING3');
  }

  async verifyHeader() {
    await Verifier.expectContainText(this.header, 'Product Overview');
  }

  async verifyProductTitle(expectedTitle: string) {
    await Verifier.expectToHaveValue(this.titleInput, expectedTitle);
  }

  get details() {
    return {
      waitForEditorReady: async () => await Verifier.expectIsVisible(this.toolbar),
    };
  }
}
