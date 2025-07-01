import { expect, Locator, Page } from '@playwright/test';

export class Utils {
  private page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async forceClick(elementToClick: Locator, elementToValidate: Locator) {
    let condition = true;
    while (condition) {
      await elementToClick.click();

      await expect(elementToValidate)
        .toBeVisible()
        .then(() => {
          condition = false;
        })
        .catch(() => {
          condition = true;
        });
    }
  }

  async incrementID(str: string) {
    const match = str!.trim().match(/^(.*?)(\d+)$/);

    if (match) {
      const prefix = match[1];
      const number = match[2];
      const incremented = String(Number(number) + 1).padStart(number.length, '0');
      return prefix + incremented;
    } else return str + '01';
  }

  async scrollToTop() {
    await this.page.evaluate(() => {
      scrollTo(document.body.scrollHeight, document.body.scrollHeight);
    });
  }

  async paintElement(locator: Locator) {
    await locator.evaluate((lo) => {
      lo.style.outline = '3px solid red';
      lo.style.backgroundColor = 'yellow';
    });
  }

  async sleep(seconds: number = 1) {
    await this.page.waitForTimeout(seconds * 1000);
  }
}
