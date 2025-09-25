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

  async scrollToBottom() {
    await this.page.evaluate(() => {
      window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' });
    });
  }

  async paintElement(locator: Locator) {
    await locator.evaluate((lo) => {
      lo.style.outline = '3px solid red';
      lo.style.backgroundColor = 'yellow';
    });
  }

  async sleep(seconds: number = 1) {
    await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
  }

  async waitForLoadingBar(timeout = 10_000) {
    const divConnectted = 'div.phx-connected';
    await this.page.locator(divConnectted).nth(1).waitFor({ state: 'attached', timeout });
  }

  async writeWithDelay(searchInput: Locator, text: string, delay = 100) {
    await searchInput.pressSequentially(text, { delay });
  }
}

