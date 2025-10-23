import { Table } from '@core/Table';
import { Utils } from '@core/Utils';
import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class AdminDashboardPO {
  private readonly utils: Utils;
  private readonly table: Table;
  private readonly searchInput: Locator;

  constructor(private readonly page: Page) {
    this.utils = new Utils(this.page);
    this.table = new Table(this.page);
    this.searchInput = this.page.locator('#text-search-input');
  }

  async clickInAccess(access: string) {
    const l = this.page.getByRole('link', { name: access });
    await l.click();
  }

  async verifyTitle(title: string, level = 3) {
    const l = this.page.getByRole('heading', {
      name: title,
      exact: true,
      level,
    });
    await Verifier.expectIsVisible(l);
  }

  async search(text: string) {
    await this.utils.writeWithDelay(this.searchInput, text);
  }

  async openResult(name: string) {
    await this.page.getByRole('link', { name: name, exact: true }).click();
    await this.utils.waitForLoadingBar();
  }

  async getValueFromTable(row: number, column: number) {
    return await this.table.getTextCell(row, column);
  }

  async getRowFromTable(row: number) {
    return await this.table.getDataOneRow(row);
  }

  async fillInput(labelText: string, value: string) {
    const l = this.page.getByLabel(labelText, { exact: true });
    await l.fill(value);
  }

  async clickInButton(labelText: string) {
    const l = this.page.getByRole('button', { name: labelText, exact: true });
    await l.click();
  }

  async clickInCheckbox(labelText: string) {
    const l = this.page.getByRole('checkbox', { name: labelText, exact: true });
    await l.check();
  }
}
