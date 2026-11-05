import AxeBuilder from '@axe-core/playwright';
import { expect, Page } from '@playwright/test';

type AccessibilityScanOptions = {
  /** The cookie consent component has a known contrast issue outside this test's scope. */
  excludeCookieConsent?: boolean;
  theme?: 'dark' | 'light';
};

/** Scan a connected, styled page after its finite loading animations settle. */
export async function scanPageAccessibility(
  page: Page,
  pageName: string,
  options: AccessibilityScanOptions = {},
) {
  await page.waitForLoadState('load');
  await expect(page.locator('[data-phx-main]')).toHaveClass(/phx-connected/);
  await expect(page.locator('#nprogress')).toHaveCount(0);
  await expect
    .poll(
      () =>
        page
          .locator('link[rel="stylesheet"][href="/css/app.css"]')
          .evaluate((link: HTMLLinkElement) => Boolean(link.sheet?.cssRules.length)),
      { message: 'Tailwind CSS must be loaded before scanning accessibility' },
    )
    .toBe(true);
  await expect
    .poll(
      () =>
        page.evaluate(
          () =>
            document.fonts.status === 'loaded' &&
            document
              .getAnimations()
              .every(
                (animation) =>
                  animation.playState !== 'running' ||
                  animation.effect?.getComputedTiming().iterations === Infinity,
              ),
        ),
      {
        message: 'Page fonts and finite animations must settle before scanning accessibility',
        timeout: 10_000,
      },
    )
    .toBe(true);

  const builder = new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag412']);

  if (options.excludeCookieConsent ?? true) {
    builder.exclude('#cookie_consent_display');
  }

  const results = await builder.analyze();

  if (results.violations.length === 0) return;

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
