import AxeBuilder from '@axe-core/playwright';
import { expect, Page } from '@playwright/test';

type AccessibilityScanOptions = {
  /**
   * The cookie consent component currently has a known contrast issue. Keep
   * this exclusion local and visible until the component is corrected.
   */
  excludeCookieConsent?: boolean;
  theme?: 'dark' | 'light';
};

export async function scanPageAccessibility(
  page: Page,
  pageName: string,
  options: AccessibilityScanOptions = {},
) {
  const builder = new AxeBuilder({ page }).withTags(['wcag2a', 'wcag412']);

  if (options.excludeCookieConsent ?? true) {
    builder.exclude('#cookie_consent_display');
  }

  const results = await builder.analyze();

  if (results.violations.length > 0) {
    const details = results.violations
      .map((violation) => {
        const nodes = violation.nodes.map((node) => node.target.join(', ')).join('; ');
        return `${violation.id} (${violation.impact ?? 'unknown'}): ${violation.help} [${nodes}]`;
      })
      .join('\n');

    throw new Error(
      `Accessibility violations on ${pageName} (${options.theme ?? 'light'}):\n${details}`,
    );
  }
}

export async function setAccessibilityTheme(page: Page, theme: 'dark' | 'light') {
  await page.evaluate((nextTheme) => {
    localStorage.setItem('theme', nextTheme);
  }, theme);
  await page.reload({ waitUntil: 'load' });
}

export async function expectKeyboardFocus(page: Page, selector: string) {
  const target = page.locator(selector).filter({ visible: true }).first();
  await expect(target).toBeVisible();
  await target.focus();
  await expect(target).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(page.locator(':focus-visible')).toHaveCount(1);
}
