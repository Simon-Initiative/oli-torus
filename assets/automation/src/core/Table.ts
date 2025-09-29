import { Locator, Page } from '@playwright/test';

export class Table {
  private readonly header: Locator;
  private readonly body: Locator;
  private readonly tr: Locator;
  private readonly td: Locator;
  private readonly th: Locator;

  constructor(page: Page) {
    this.header = page.locator('thead');
    this.body = page.locator('tbody');
    this.tr = page.locator('tr');
    this.td = page.locator('td');
    this.th = page.locator('th');
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

  async getTextCell(row: number, column: number) {
    const data = await this.getDataAllRows();
    return data[row - 1][column - 1];
  }
}
