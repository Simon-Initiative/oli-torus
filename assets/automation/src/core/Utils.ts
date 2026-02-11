import { Locator, Page } from '@playwright/test';
import { Verifier } from './verify/Verifier';
import { Waiter } from './wait/Waiter';

export class Utils {
  constructor(private readonly page?: Page) {
    this.page = page;
  }

  async forceClick(
    elementToClick: Locator,
    elementToValidate: Locator,
    maxAttempts = 5,
    waitMs = 200,
  ) {
    for (let i = 0; i < maxAttempts; i++) {
      await elementToClick.click({ force: true });
      try {
        await Verifier.expectIsVisible(elementToValidate, "Force click didn't work");
        return;
      } catch {
        if (i === maxAttempts - 1) {
          throw new Error(`forceClick failed after ${maxAttempts} attempts`);
        }
        await this.page?.waitForTimeout(waitMs);
      }
    }
  }

  incrementID(str: string) {
    const regex = /^(.*?)(\d+)$/;
    const match = regex.exec(str.trim());

    if (match) {
      const prefix = match[1];
      const number = match[2];
      const incremented = String(Number(number) + 1).padStart(number.length, '0');
      return prefix + incremented;
    } else return str + '01';
  }

  async scrollToBottom() {
    await this.page.evaluate(() => {
      scrollTo(0, document.body.scrollHeight);
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

  async waitForLoadingBar() {
    const connected = 'div.phx-connected';
    const loading = 'div.phx-loading';

    await Waiter.waitForLoadState(this.page);

    const divLoading = await this.page.locator(loading).all();
    const divConnected = this.page.locator(connected);

    await Verifier.expectToHaveCount(divConnected, divLoading.length);
  }

  async writeWithDelay(searchInput: Locator, text: string, delay = 100) {
    await searchInput.pressSequentially(text, { delay });
  }

  format(str: string, placeholder: string, ...values: string[]) {
    const escapedPlaceholder = placeholder.replace(/[-/\\^$*+?.()|[\]{}]/g, '$&');
    const regex = new RegExp(escapedPlaceholder, 'g');
    const placeholderCount = (str.match(regex) || []).length;

    if (placeholderCount !== values.length) {
      const msg = `Expected ${placeholderCount} values for placeholder '${placeholder}', but ${values.length} were provided.`;
      throw new Error(`${msg}. \n${str}`);
    }

    let i = 0;
    return str.replace(regex, () => values[i++] ?? '');
  }

  async modalDisappears() {
    const modalClass = '.modal-backdrop.fade.show';
    const modalBackdrop = this.page.locator(modalClass);
    try {
      await Waiter.waitFor(modalBackdrop, 'hidden');
    } catch {
      await this.page.reload();
      console.log(`Element: ${modalClass}. Restart page to remove modal shadow`);
    }
  }
}
