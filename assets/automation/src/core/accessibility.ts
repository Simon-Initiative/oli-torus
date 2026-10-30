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
    const readStyles = () => {
      const computed = window.getComputedStyle(element);
      return {
        outline: {
          style: computed.outlineStyle,
          width: computed.outlineWidth,
          color: computed.outlineColor,
        },
        boxShadow: computed.boxShadow,
        borders: [
          {
            color: computed.borderTopColor,
            style: computed.borderTopStyle,
            width: computed.borderTopWidth,
          },
          {
            color: computed.borderRightColor,
            style: computed.borderRightStyle,
            width: computed.borderRightWidth,
          },
          {
            color: computed.borderBottomColor,
            style: computed.borderBottomStyle,
            width: computed.borderBottomWidth,
          },
          {
            color: computed.borderLeftColor,
            style: computed.borderLeftStyle,
            width: computed.borderLeftWidth,
          },
        ],
      };
    };

    const hasVisibleColor = (value: string) => {
      if (!value || value.toLowerCase() === 'transparent') return false;

      const alpha = value.match(/rgba?\((?:[^,]+,){3}\s*([^,)]+)/i)?.[1];
      return alpha === undefined || Number.parseFloat(alpha) > 0;
    };

    const hasVisibleBoxShadow = (value: string) =>
      value !== 'none' &&
      value.split(/,(?![^()]*\))/).some((shadow) => {
        if (!hasVisibleColor(shadow)) return false;

        const dimensions = shadow
          .replace(/rgba?\([^)]*\)|hsla?\([^)]*\)|#[0-9a-f]+|\b[a-z]+\b/gi, '')
          .match(/-?(?:\d+\.?\d*|\.\d+)/g);

        return dimensions?.some((dimension) => Number.parseFloat(dimension) !== 0) ?? false;
      });

    const originalTransition = element.style.getPropertyValue('transition');
    const originalTransitionPriority = element.style.getPropertyPriority('transition');
    element.style.setProperty('transition', 'none', 'important');

    const focusedStyles = readStyles();
    const wasFocused = document.activeElement === element;

    if (wasFocused) element.blur();
    const unfocusedStyles = readStyles();

    if (originalTransition) {
      element.style.setProperty('transition', originalTransition, originalTransitionPriority);
    } else {
      element.style.removeProperty('transition');
    }

    if (wasFocused) element.focus({ preventScroll: true });

    const hasOutline =
      focusedStyles.outline.style !== 'none' &&
      Number.parseFloat(focusedStyles.outline.width) > 0 &&
      hasVisibleColor(focusedStyles.outline.color);

    const hasBoxShadow = hasVisibleBoxShadow(focusedStyles.boxShadow);

    const hasBorderChange = focusedStyles.borders.some((focusedBorder, index) => {
      const unfocusedBorder = unfocusedStyles.borders[index];
      const hasVisibleBorder =
        Number.parseFloat(focusedBorder.width) > 0 && hasVisibleColor(focusedBorder.color);

      return (
        hasVisibleBorder &&
        (focusedBorder.color !== unfocusedBorder.color ||
          focusedBorder.style !== unfocusedBorder.style ||
          focusedBorder.width !== unfocusedBorder.width)
      );
    });

    return hasOutline || hasBoxShadow || hasBorderChange;
  });

  expect(hasVisibleFocusIndicator).toBe(true);
}
