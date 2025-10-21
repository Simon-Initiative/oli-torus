import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class SelectPageCO {
  private readonly dialog: Locator;
  private readonly dialogTitle: Locator;
  private readonly combobox: Locator;
  private readonly selectButton: Locator;

  constructor(page: Page) {
    this.dialog = page.getByRole('dialog');
    this.dialogTitle = this.dialog.getByText('Select a Page');
    this.combobox = page.getByRole('combobox');
    this.selectButton = page.getByRole('button', { name: 'Select' });
  }

  async expectDialogTitle() {
    await Verifier.expectIsVisible(this.dialogTitle);
  }

  async selectPageLink(visibleText: string) {
    await this.combobox.selectOption({ label: visibleText });
  }

  async confirm() {
    await this.selectButton.click();
  }
}
