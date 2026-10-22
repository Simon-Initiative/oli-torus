import AxeBuilder from '@axe-core/playwright';
import { Page, expect } from '@playwright/test';

type AccessibilityScanOptions = {
  /** The cookie consent component has a known contrast issue outside this test's scope. */
  excludeCookieConsent?: boolean;
  theme?: 'dark' | 'light';
};

export async function scanPageAccessibility(
  page: Page,
  pageName: string,
  options: AccessibilityScanOptions = {},
) {
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

  const focused = page.locator(':focus-visible');
  await expect(focused).toHaveCount(1);
  await expect(focused).toBeVisible();

  const hasVisibleFocusIndicator = await focused.evaluate((element) => {
    const properties = [
      'outlineStyle',
      'outlineWidth',
      'outlineColor',
      'outlineOffset',
      'boxShadow',
      'borderTopColor',
      'borderRightColor',
      'borderBottomColor',
      'borderLeftColor',
      'borderTopWidth',
      'borderRightWidth',
      'borderBottomWidth',
      'borderLeftWidth',
      'backgroundColor',
      'color',
      'textDecorationLine',
      'textDecorationStyle',
      'textDecorationColor',
      'textDecorationThickness',
      'textUnderlineOffset',
      'opacity',
      'transform',
    ] as const;

    const readStyles = () => {
      const computed = window.getComputedStyle(element);
      return properties.map((property) => computed[property]);
    };

    const focusedStyles = readStyles();
    const wasFocused = document.activeElement === element;

    if (wasFocused) element.blur();
    const unfocusedStyles = readStyles();
    if (wasFocused) element.focus({ preventScroll: true });

    return focusedStyles.some((value, index) => value !== unfocusedStyles[index]);
  });

  expect(hasVisibleFocusIndicator).toBe(true);
}
