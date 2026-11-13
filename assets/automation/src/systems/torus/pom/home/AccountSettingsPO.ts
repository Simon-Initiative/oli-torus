import { step } from '@core/decoration/step';
import { expect, Locator, Page } from '@playwright/test';

/**
 * The learner Account Settings page (/users/settings): name, email and password share a
 * single form and Update button.
 */
export class AccountSettingsPO {
  private readonly heading: Locator;
  private readonly givenName: Locator;
  private readonly familyName: Locator;
  private readonly email: Locator;
  private readonly currentPassword: Locator;
  private readonly newPassword: Locator;
  private readonly passwordConfirmation: Locator;
  private readonly updateButton: Locator;
  private readonly backLink: Locator;

  constructor(private readonly page: Page) {
    this.heading = page.getByRole('heading', { name: 'Account Settings', exact: true });
    this.givenName = page.locator('#settings_form #given_name');
    this.familyName = page.locator('#settings_form #family_name');
    this.email = page.locator('#settings_form #email');
    this.currentPassword = page.locator('#settings_form #current_password_for_password');
    this.newPassword = page.locator('#settings_form #password');
    this.passwordConfirmation = page.locator('#settings_form #password_confirmation');
    this.updateButton = page.locator('#settings_form').getByRole('button', { name: 'Update' });
    this.backLink = page.getByRole('link', { name: 'Back', exact: true });
  }

  async expectLoaded() {
    await expect(this.page).toHaveURL((url) => url.pathname === '/users/settings');
    await expect(this.heading).toBeVisible();
    await expect(this.page.locator('[data-phx-main]')).toHaveClass(/phx-connected/);
  }

  @step('Update the account name to {givenName} {familyName}')
  async updateName(givenName: string, familyName: string) {
    await this.givenName.fill(givenName);
    await this.familyName.fill(familyName);
    await this.updateButton.click();
    await expect(this.page.getByText('Account details updated')).toBeVisible();
  }

  async expectName(givenName: string, familyName: string) {
    await expect(this.givenName).toHaveValue(givenName);
    await expect(this.familyName).toHaveValue(familyName);
  }

  /** Requests the change; the new email only applies once the emailed link is opened. */
  @step('Request an email change to {newEmail}')
  async requestEmailChange(newEmail: string, currentPassword: string) {
    await this.email.fill(newEmail);
    await this.currentPassword.fill(currentPassword);
    await this.updateButton.click();
    await expect(this.page.getByText('Email confirmation sent')).toBeVisible();
  }

  /** Opens the link from the confirmation email, which applies the change and returns here. */
  @step('Confirm the email change')
  async confirmEmailChange(link: string) {
    await this.page.goto(link);
    await expect(this.page.getByText('Email changed successfully.')).toBeVisible();
    await this.expectLoaded();
  }

  async expectEmail(email: string) {
    await expect(this.email).toHaveValue(email);
  }

  /** Saving a new password signs the student in again and returns to Account Settings. */
  @step('Change the password')
  async changePassword(currentPassword: string, newPassword: string) {
    await this.currentPassword.fill(currentPassword);
    await this.newPassword.fill(newPassword);
    await this.passwordConfirmation.fill(newPassword);
    await this.updateButton.click();
    await expect(this.page.getByText('Password updated successfully!')).toBeVisible();
    await this.expectLoaded();
  }

  @step('Reload Account Settings')
  async reload() {
    await this.page.reload();
    await this.expectLoaded();
  }

  @step('Go back from Account Settings')
  async goBack() {
    await this.backLink.click();
  }
}
