import { Table } from '@core/Table';
import { Utils } from '@core/Utils';
import { Verifier } from '@core/verify/Verifier';
import { expect, Locator, Page } from '@playwright/test';

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

  async openResultWithText(rowText: string, name: string) {
    const row = this.page.getByRole('row').filter({ hasText: rowText });
    await row.getByRole('link', { name, exact: true }).click();
    await expect(this.page).toHaveURL(/\/admin\/authors\/\d+$/);
  }

  // A click before LiveView connects is dropped, so retry until the form unlocks.
  async startEdit() {
    const edit = this.page.getByRole('button', { name: 'Edit', exact: true });

    await expect(async () => {
      if (await edit.isVisible()) await edit.click({ timeout: 1_000 }).catch(() => undefined);
      await expect(this.page.locator('#given_name')).toBeEnabled({ timeout: 1_000 });
    }).toPass({ timeout: 15_000 });
  }

  async selectSystemRole(label: string) {
    await this.systemRoleSelect.selectOption({ label });
  }

  async expectSystemRole(label: string) {
    await expect(this.systemRoleSelect.locator('option:checked')).toHaveText(label);
  }

  async expectSystemRoleLocked() {
    await expect(this.page.locator('#given_name')).toBeEnabled();
    await expect(this.systemRoleSelect).toBeDisabled();
  }

  async expectFlash(message: string) {
    await expect(this.page.getByText(message, { exact: true })).toBeVisible();
  }

  private get systemRoleSelect() {
    return this.page.locator('select[name="author[system_role_id]"]');
  }
}
