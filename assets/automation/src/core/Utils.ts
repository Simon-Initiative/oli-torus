import { expect, Locator, Page } from '@playwright/test';

export class Utils {
  private page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async sleep(seconds: number) {
    await this.page.waitForTimeout(seconds * 1000);
  }

  async forceclick(elementToclick: Locator, elementToValidate: Locator) {
    let condition = true;
    while (condition) {
      await elementToclick.click();

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

  async incrementID(name: string) {
    const match = name!.trim().match(/^(.*?)(\d+)$/);

    if (match) {
      const prefix = match[1];
      const number = match[2];
      const incremented = String(Number(number) + 1).padStart(number.length, '0');
      return prefix + incremented;
    } else return name + '01';
  }
}
