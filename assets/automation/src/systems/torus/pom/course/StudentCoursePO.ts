import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class StudentCoursePO {
  private readonly myAssignment: Locator;
  private readonly viewSelector: Locator;
  private readonly onboardingWizard: Locator;
  private readonly automationBypass: Locator;

  constructor(private readonly page: Page) {
    this.myAssignment = page.locator('role="my assignments"');
    this.viewSelector = page.locator('#view_selector');
    this.onboardingWizard = page.locator('#student-onboarding-wizard');
    this.automationBypass = page.locator('#automation-go-to-course');
  }

  async presentAssignmentBlock() {
    await Verifier.expectIsVisible(this.myAssignment);
  }

  async presentViewSelector() {
    await Verifier.expectIsVisible(this.viewSelector);
  }

  async presentPage(pageName: string) {
    const l = this.page.getByRole('heading', { name: pageName, exact: true, level: 5 });
    await Verifier.expectIsVisible(l);
  }

  async goToCourseIfPrompted() {
    const wizard = this.onboardingWizard;
    const headerLink = this.page.locator('#header_logo_button');

    // Try hidden automation bypass first (added specifically for automation).
    const bypassVisible = await this.automationBypass.isVisible({ timeout: 1000 }).catch(() => false);
    if (bypassVisible) {
      await this.automationBypass.click({ force: true, timeout: 3000 }).catch(() => undefined);
      await this.page.waitForURL('**/sections/**', { timeout: 15000 }).catch(() => undefined);
      await wizard.waitFor({ state: 'hidden', timeout: 5000 }).catch(() => undefined);
      return;
    }

    // If the wizard is visible, prefer navigating via the header section link which bypasses LiveView steps.
    const wizardVisible = await wizard.isVisible({ timeout: 2000 }).catch(() => false);
    if (wizardVisible) {
      const href = await headerLink.getAttribute('href').catch(() => null);
      if (href) {
        await headerLink.click({ timeout: 5000 }).catch(() => undefined);
        await this.page.waitForURL('**/sections/**', { timeout: 15000 }).catch(() => undefined);
        await wizard.waitFor({ state: 'hidden', timeout: 5000 }).catch(() => undefined);
        return;
      }
    }

    // Fallback to clicking wizard CTA if header link not available.
    const buttonMatcher = /go to course|start survey|let's begin|continue|next/i;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const visible = await wizard.isVisible({ timeout: 2000 }).catch(() => false);
      if (!visible) break;

      const cta = wizard.locator('button', { hasText: buttonMatcher }).first();
      if (!(await cta.isVisible({ timeout: 3000 }).catch(() => false))) break;

      await cta.scrollIntoViewIfNeeded().catch(() => undefined);
      await cta.click({ timeout: 5000, force: true }).catch(() => undefined);

      const closed = await Promise.race([
        wizard.waitFor({ state: 'detached', timeout: 10000 }).then(() => true).catch(() => false),
        wizard.waitFor({ state: 'hidden', timeout: 10000 }).then(() => true).catch(() => false),
        this.page.waitForURL('**/sections/**', { timeout: 10000 }).then(() => true).catch(() => false),
      ]);
      if (closed) break;
      await this.page.waitForTimeout(1000);
    }
  }
}
