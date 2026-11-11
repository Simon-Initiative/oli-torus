import { step } from '@core/decoration/step';
import { expect, Locator, Page } from '@playwright/test';

/**
 * The research consent form (/research_consent). The choice is saved on the account; without
 * a return path the form sends the student to their courses workspace.
 */
export class ResearchConsentPO {
  private readonly agree: Locator;
  private readonly disagree: Locator;
  private readonly submitButton: Locator;

  constructor(private readonly page: Page) {
    this.agree = page.getByRole('radio', { name: 'I Agree' });
    this.disagree = page.getByRole('radio', { name: 'I Disagree' });
    this.submitButton = page.getByRole('button', { name: 'Submit', exact: true });
  }

  async expectLoaded() {
    await expect(this.page).toHaveURL((url) => url.pathname === '/research_consent');
    await expect(this.submitButton).toBeVisible();
  }

  @step('Submit research consent {agrees}')
  async submit(agrees: boolean) {
    await (agrees ? this.agree : this.disagree).check();
    await Promise.all([
      this.page.waitForURL((url) => url.pathname !== '/research_consent'),
      this.submitButton.click(),
    ]);
  }

  async expectConsent(agrees: boolean) {
    await expect(this.agree).toBeChecked({ checked: agrees });
    await expect(this.disagree).toBeChecked({ checked: !agrees });
  }
}
