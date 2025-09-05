import { Locator, Page } from '@playwright/test';

export class TableCO {
  private readonly table: Locator;
  private readonly captionTable: Locator;
  private readonly captionTablePreview: Locator;

  constructor(page: Page) {
    this.table = page.locator('table');
    this.captionTable = page.getByRole('paragraph').filter({ hasText: 'Caption (optional)' });
    this.captionTablePreview = page.locator('figcaption');
  }

  async fillCaptionTable(text: string) {
    await this.captionTable.fill(text);
  }

  async getCaptionTable() {
    return await this.captionTablePreview.innerText();
  }

  async fillCell(row: number, column: number, text: string) {
    const cell = this.table
      .locator('tr')
      .nth(row - 1)
      .locator('td')
      .nth(column - 1);
    await cell.fill(text);
  }

  async getContentCell(row: number, column: number) {
    const cell = this.table
      .locator('tr')
      .nth(row - 1)
      .locator('td')
      .nth(column - 1);
    return await cell.innerText();
  }

  async getContentHead(row: number, column: number) {
    const cell = this.table
      .locator('tr')
      .nth(row - 1)
      .locator('th')
      .nth(column - 1);
    return await cell.innerText();
  }
}
