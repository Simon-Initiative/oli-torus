import { Locator, Page } from '@playwright/test';
import { Utils } from './Utils';

export class Table {
  private readonly header: Locator;
  private readonly body: Locator;
  private readonly tr: Locator;
  private readonly td: Locator;
  private readonly th: Locator;
  private readonly caption: Locator;
  private readonly utils: Utils;

  constructor(page: Page) {
    this.header = page.locator('thead');
    this.body = page.locator('tbody');
    this.tr = page.locator('tr');
    this.td = page.locator('td');
    this.th = page.locator('th');
    this.caption = page.locator('p span[data-slate-placeholder]:has-text("Caption (optional)")');
    this.utils = new Utils(page);
  }

  async getColumnTitles() {
    return await this.header.locator(this.th).allTextContents();
  }

  async getDataAllRows() {
    const rows = await this.body.locator(this.tr).all();
    const data: string[][] = [];

    for (const row of rows) {
      const cells = (await row.locator(this.td).allTextContents()).map((cell) => cell.trim());
      data.push(cells);
    }

    return data;
  }

  async getDataOneRow(row: number) {
    const rows = await this.getDataAllRows();
    return rows[row - 1];
  }

  async getTextCell(row: number, column: number) {
    const data = await this.getDataAllRows();
    return data?.[row - 1]?.[column - 1];
  }

  async fillCell(row: number, column: number, text: string) {
    const cell = this.body
      .locator(this.tr)
      .nth(row - 1)
      .locator(this.td)
      .nth(column - 1);
    await cell.fill(text);
  }

  async fillCaptionTable(text: string) {
    await this.utils.writeWithDelay(this.caption, text);
  }

  async getCellLocator(row: number, column: number) {
    const rows = await this.body.locator(this.tr).all();
    return rows[row - 1]?.locator(this.td).nth(column - 1);
  }
}
