import { BrowserContext, expect, Page } from '@playwright/test';

export type CredentialAccountType = 'author' | 'user';

type AccountDetails = {
  email: string;
  familyName: string;
  givenName: string;
  password: string;
};

export class CredentialAccountPO {
  constructor(
    private readonly page: Page,
    private readonly type: CredentialAccountType,
  ) {}

  async register(account: AccountDetails) {
    await this.page.goto(`/${this.pathSegment()}/register`);

    const form = this.page.locator('#registration_form');
    await form.locator(`input[name="${this.formName()}[email]"]`).fill(account.email);
    await form.locator(`input[name="${this.formName()}[given_name]"]`).fill(account.givenName);
    await form.locator(`input[name="${this.formName()}[family_name]"]`).fill(account.familyName);
    await form.locator(`input[name="${this.formName()}[password]"]`).fill(account.password);
    await form
      .locator(`input[name="${this.formName()}[password_confirmation]"]`)
      .fill(account.password);

    await this.acceptCookieConsentIfVisible();
    await form.getByRole('button', { name: 'Create account', exact: true }).click();
    await this.page.waitForURL(`/${this.pathSegment()}/confirm`, { waitUntil: 'commit' });
  }

  async confirm(url: string) {
    await this.page.goto(url);
    await this.acceptCookieConsentIfVisible();
    await this.page.getByRole('button', { name: 'Confirm', exact: true }).click();
    await this.page.waitForURL(`/${this.pathSegment()}/log_in`, { waitUntil: 'commit' });
    await expect(this.page.getByText('Email successfully confirmed.')).toBeVisible();
  }

  async requestPasswordReset(email: string) {
    await this.page.goto(`/${this.pathSegment()}/reset_password`);

    const form = this.page.locator('#reset_password_form');
    await form.locator(`input[name="${this.formName()}[email]"]`).fill(email);
    await this.acceptCookieConsentIfVisible();
    await form.getByRole('button', { name: 'Send password reset instructions' }).click();
    await this.page.waitForURL(this.resetRequestDestination());
  }

  async resetPassword(url: string, password: string) {
    await this.page.goto(url);

    const form = this.page.locator('#reset_password_form');
    await form.locator(`input[name="${this.formName()}[password]"]`).fill(password);
    await form.locator(`input[name="${this.formName()}[password_confirmation]"]`).fill(password);
    await this.acceptCookieConsentIfVisible();
    await form.getByRole('button', { name: 'Reset Password', exact: true }).click();
    await this.page.waitForURL(`/${this.pathSegment()}/log_in`, { waitUntil: 'commit' });
    await expect(this.page.getByText('Password reset successfully.')).toBeVisible();
  }

  async login(email: string, password: string, loginPath?: string) {
    await this.page.goto(loginPath ?? `/${this.pathSegment()}/log_in`);

    const form = this.page.locator('#login_form');
    await form.locator(`input[name="${this.formName()}[email]"]`).fill(email);
    await form.locator(`input[name="${this.formName()}[password]"]`).fill(password);
    await this.acceptCookieConsentIfVisible();
    await form.getByRole('button', { name: 'Sign in', exact: true }).click();
  }

  async expectLoginFailure() {
    await this.page.waitForURL(`/${this.pathSegment()}/log_in`);
    await expect(this.page.getByText('Invalid email or password')).toBeVisible();
  }

  async expectLoginSuccess(destination?: string) {
    await this.page.waitForURL(destination ?? this.destinationPath());
  }

  async expectAccountLabel(label: string) {
    await expect(this.page.locator('[role="account label"]')).toHaveText(label);
  }

  // Clears only the session cookie so a confirmation/reset link is followed
  // anonymously, without wiping the cookie-consent choice and re-triggering
  // the consent modal on the next navigation.
  async clearSessionCookie(context: BrowserContext) {
    await context.clearCookies({ name: '_oli_key' });
  }

  pathSegment(): 'authors' | 'users' {
    return this.type === 'author' ? 'authors' : 'users';
  }

  private formName() {
    return this.type;
  }

  private destinationPath() {
    return this.type === 'author' ? '/workspaces/course_author' : '/workspaces/student';
  }

  private resetRequestDestination() {
    return this.type === 'author' ? '/authors/log_in' : '/';
  }

  private async acceptCookieConsentIfVisible() {
    const consent = this.page.locator('#cookie_consent_display');
    const acceptButton = consent.getByRole('button', { name: 'Accept', exact: true });

    if (await acceptButton.isVisible({ timeout: 1_000 }).catch(() => false)) {
      await acceptButton.click({ force: true });
      await expect(consent).toBeHidden();
    }
  }
}
