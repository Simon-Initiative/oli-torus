import { step } from '@core/decoration/step';
import { expect, Locator, Page } from '@playwright/test';

export type ThemeMode = 'auto' | 'light' | 'dark';

const MENU_ID = 'mobile-user-account-menu-sidebar';

/**
 * The student user menu below the sm breakpoint, opened from the mobile course menu. Theme is
 * stored in the browser; the other settings are saved on the account. On a phone the menu is
 * taller than the screen, so its top rows (Back, Account Settings, My Courses) are not driven.
 */
export class MobileUserMenuCO {
  private readonly dropdown: Locator;
  private readonly mathPreviews: Locator;
  private readonly timezone: Locator;

  constructor(private readonly page: Page) {
    this.dropdown = page.locator(`#${MENU_ID}-dropdown`);
    this.mathPreviews = this.dropdown.getByRole('checkbox', { name: 'Show Math Previews' });
    this.timezone = this.dropdown.getByRole('combobox', { name: 'Select timezone' });
  }

  async expectClosed() {
    await expect(this.dropdown).toBeHidden();
  }

  @step('Open Research Consent from the user menu')
  async goToResearchConsent() {
    await Promise.all([
      this.page.waitForURL((url) => url.pathname === '/research_consent'),
      this.dropdown.getByRole('link', { name: 'Research Consent' }).click(),
    ]);
  }

  @step('Open the cookie preferences from the user menu')
  async goToCookiePreferences() {
    await Promise.all([
      this.page.waitForURL((url) => url.pathname === '/cookie-preferences'),
      this.dropdown.getByRole('button', { name: 'Cookies' }).click(),
    ]);
  }

  @step('Sign out from the user menu')
  async signOut() {
    const currentUrl = this.page.url();
    await Promise.all([
      this.page.waitForURL((url) => url.toString() !== currentUrl),
      this.dropdown.getByRole('link', { name: 'Sign Out' }).click(),
    ]);
  }

  @step('Select the {mode} theme')
  async selectTheme(mode: ThemeMode) {
    // The radio input is visually hidden; its label is the control students tap.
    await this.dropdown.locator(`label[for="${this.themeInputId(mode)}"]`).click();
    await this.expectTheme(mode);
  }

  async expectTheme(mode: ThemeMode) {
    await expect(this.dropdown.locator(`#${this.themeInputId(mode)}`)).toBeChecked();
  }

  /** The dark theme is applied to the whole page through a class on the root element. */
  async expectDarkThemeApplied() {
    await expect(this.page.locator('html')).toHaveClass(/(^|\s)dark(\s|$)/);
  }

  @step('Set Show Math Previews to {enabled}')
  async setShowMathPreviews(enabled: boolean) {
    await expect(this.mathPreviews).toBeChecked({ checked: !enabled });
    // Toggling submits the preference form, which redirects back to the current page.
    await Promise.all([this.page.waitForEvent('load'), this.mathPreviews.click()]);
  }

  async expectShowMathPreviews(enabled: boolean) {
    await expect(this.mathPreviews).toBeChecked({ checked: enabled });
  }

  /**
   * Moves the timezone selection one option down and returns the new value. The select
   * only submits on trusted change events, so it is driven with the keyboard rather than
   * with selectOption.
   */
  @step('Change the timezone to the next option')
  async selectNextTimezone() {
    await expect(this.timezone).toBeVisible();
    const current = await this.timezone.inputValue();
    const next = await this.timezone.evaluate(
      (select: HTMLSelectElement) => select.options[select.selectedIndex + 1]?.value ?? '',
    );
    expect(next, `No timezone option after ${current}`).toBeTruthy();

    await this.timezone.focus();
    await Promise.all([this.page.waitForEvent('load'), this.page.keyboard.press('ArrowDown')]);
    return next;
  }

  async expectTimezone(value: string) {
    await expect(this.timezone).toHaveValue(value);
  }

  private themeInputId(mode: ThemeMode) {
    return `${MENU_ID}-menu-items-admin-dark-mode-selector-${mode}`;
  }
}
