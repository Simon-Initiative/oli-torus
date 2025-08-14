import { Locator, Page, expect } from '@playwright/test';

export class SelectPageCO {
  private readonly dialog: Locator;
  private readonly dialogTitle: Locator;
  private readonly combobox: Locator;
  private readonly selectButton: Locator;
  private readonly cancelButton: Locator;

  constructor(private page: Page) {
    this.dialog = this.page.getByRole('dialog');
    this.dialogTitle = this.dialog.getByText('Select a Page');
    this.combobox = this.page.getByRole('combobox');
    this.selectButton = page.getByRole('button', { name: 'Select' });
    this.cancelButton = this.page.getByRole('button', { name: 'Cancel' });
  }

  async expectDialogTitle() {
    await expect(this.dialogTitle).toBeVisible();
  }

  async selectPageLink(visibleText: string) {
    await this.combobox.selectOption({ label: visibleText });
  }

  async confirm() {
    await this.selectButton.click();
  }

  async cancel() {
    await this.cancelButton.click();
  }
}
