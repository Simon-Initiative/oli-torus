import { Verifier } from '@core/verify/Verifier';
import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';
import { NavbarCO } from '@pom/home/NavbarCO';
import { TYPE_USER, TypeUser } from '@pom/types/type-user';

export class LoginPO {
  private readonly acceptCookiesButton: Locator;
  private readonly welcomeText: Locator;
  private readonly mainContent: Locator;
  private readonly emailInput: Locator;
  private readonly passwordInput: Locator;
  private readonly signInButton: Locator;
  private readonly welcomeTitle: Locator;

  constructor(private readonly page: Page) {
    this.acceptCookiesButton = page.locator('#cookie_consent_display button:has-text("Accept")');
    this.welcomeText = page.locator('#main-content');
    this.mainContent = page.locator('#main-content');
    this.emailInput = page.locator('#login_form_email');
    this.passwordInput = page.locator('#login_form_password');
    this.signInButton = page.locator('#login_form button:has-text("Sign in")');
    this.welcomeTitle = page.locator('main h1');
  }

  async acceptCookies() {
    try {
      await Waiter.waitFor(this.acceptCookiesButton, 'visible');
      await this.acceptCookiesButton.click();
    } catch {
      console.log("Waiting for cookie modal and it doesn't appear");
    }
  }

  async verifyTitle(expectedTitle: string) {
    await Verifier.expectTitle(this.page, expectedTitle);
  }

  async verifyWelcomeText(expectedText: string) {
    await Verifier.expectContainText(this.welcomeText, expectedText);
  }

  async verifyRole(expectedRole: string) {
    await Verifier.expectContainText(this.mainContent, expectedRole);
  }

  async fillEmail(email: string) {
    await this.waitForLoginForm();
    await this.emailInput.click();
    await this.emailInput.clear();
    await this.emailInput.fill(email);
    await Verifier.expectToHaveValue(this.emailInput, email);
  }

  async fillPassword(password: string) {
    await this.waitForLoginForm();
    await this.passwordInput.click();
    await this.passwordInput.clear();
    await this.passwordInput.fill(password);
    await Verifier.expectToHaveValue(this.passwordInput, password);
  }

  async signIn(email: string, password: string) {
    await this.waitForLoginForm();
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await Verifier.expectToHaveValue(this.emailInput, email);
    await Verifier.expectToHaveValue(this.passwordInput, password);
    await this.clickSignInButton();
  }

  async clickSignInButton() {
    await this.signInButton.click();
  }

  private async waitForLoginForm() {
    await Waiter.waitForLoadState(this.page);

    try {
      await Waiter.waitFor(this.page.locator('div.phx-connected').first(), 'attached');
      await Waiter.waitFor(this.page.locator('div.phx-loading').first(), 'detached');
    } catch {
      // Some login pages may render without a LiveView root; the form checks below are the source of truth.
    }

    await Waiter.waitFor(this.emailInput, 'visible');
    await Waiter.waitFor(this.passwordInput, 'visible');
    await Verifier.expectIsEnabled(this.emailInput);
    await Verifier.expectIsEnabled(this.passwordInput);
    await Verifier.expectIsEnabled(this.signInButton);
  }

  async selectRoleAccount(role: TypeUser) {
    const navbarco = new NavbarCO(this.page);

    if (role === TYPE_USER.student) {
      await navbarco.clickLogo();
    }

    if (role === TYPE_USER.instructor) {
      await navbarco.goToInstructorsLogin();
    }

    if (role === TYPE_USER.author || role === TYPE_USER.administrator) {
      await navbarco.goToAuthorsLogin();
    }
  }

  async verifyWelcomeTitle(expectedTitle: string) {
    await Verifier.expectContainText(this.welcomeTitle, expectedTitle);
  }
}
