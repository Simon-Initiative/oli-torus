import { Locator, Page } from '@playwright/test';

export class Waiter {
  /**
   * Waits for the page to reach a specific load state.
   * @param page The Playwright Page object.
   * @param [state='domcontentloaded'] The load state to wait for.
   * - `'load'`: Waits for the `load` event to be fired.
   * - `'domcontentloaded'`: Waits for the `DOMContentLoaded` event to be fired.
   * - `'networkidle'`: Waits until there are no network connections for at least 500 ms.
   */
  static async waitForLoadState(
    page: Page,
    state: 'load' | 'domcontentloaded' | 'networkidle' = 'domcontentloaded',
  ) {
    await page.waitForLoadState(state);
  }

  static async waitFor(
    locator: Locator,
    state: 'attached' | 'detached' | 'visible' | 'hidden',
    timeout = 5000,
  ) {
    await locator.waitFor({ state, timeout });
  }
}
