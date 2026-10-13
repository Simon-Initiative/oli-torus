import { expect, Page } from '@playwright/test';

export class AccountLinkingPO {
  private readonly form = this.page.locator('#link_account_form');

  constructor(private readonly page: Page) {}

  async link(email: string, password: string) {
    await expect(this.form).toBeVisible();
    await this.form.locator('input[name="author[email]"]').fill(email);
    await this.form.locator('input[name="author[password]"]').fill(password);
    await this.form.getByRole('button', { name: 'Link account', exact: true }).click();
  }

  async expectInvalidCredentials() {
    await expect(this.page).toHaveURL(/\/users\/link_account(?:\?.*)?$/);
    await expect(this.page.getByText('Invalid email or password', { exact: true })).toBeVisible();
  }

  async expectLinkSucceeded() {
    await expect(this.page).toHaveURL(/\/(?:users\/settings|workspaces\/instructor)$/);
    await expect(
      this.page.getByText('Your authoring account has been linked to your user account.', {
        exact: true,
      }),
    ).toBeVisible();
  }

  async expectAlreadyLinked(email: string) {
    await expect(
      this.page.getByText(`Your account is currently linked to ${email}.`, { exact: true }),
    ).toBeVisible();
    await expect(this.form).toBeHidden();
    await expect(
      this.page.getByRole('button', { name: 'Unlink account', exact: true }),
    ).toBeVisible();
  }
}
