import { step } from '@core/decoration/step';
import { expect, Locator, Page } from '@playwright/test';

export type CookieCategory = 'Functionality Cookies' | 'Analytics Cookies' | 'Targeting Cookies';

/**
 * The cookie preferences page (/cookie-preferences). For a signed-in user the choices are
 * saved on the account, so they come back on a later visit.
 */
export class CookiePreferencesPO {
  private readonly saveButton: Locator;

  constructor(private readonly page: Page) {
    this.saveButton = page.locator('#save-cookie-preferences');
  }

  async expectLoaded() {
    await expect(this.page).toHaveURL((url) => url.pathname === '/cookie-preferences');
    await expect(this.page.locator('[data-phx-main]')).toHaveClass(/phx-connected/);
    await expect(this.saveButton).toBeVisible();
  }

  @step('Set {category} to {enabled}')
  async setCategory(category: CookieCategory, enabled: boolean) {
    const toggle = this.toggle(category);
    await expect(toggle).toBeChecked({ checked: !enabled });
    await toggle.click();
    await expect(toggle).toBeChecked({ checked: enabled });
  }

  @step('Save the cookie preferences')
  async save() {
    await this.saveButton.click();
    await expect(this.page.getByText('Cookie preferences have been updated.')).toBeVisible();
  }

  async expectCategory(category: CookieCategory, enabled: boolean) {
    await expect(this.toggle(category)).toBeChecked({ checked: enabled });
  }

  private toggle(category: CookieCategory) {
    return this.page.getByRole('switch', { name: category, exact: true });
  }
}
