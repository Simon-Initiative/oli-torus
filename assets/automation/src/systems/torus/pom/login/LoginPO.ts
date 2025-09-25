import { Locator, Page, expect } from '@playwright/test';
import { NavbarCO } from '@pom/component/NavbarCO';
import { USER_TYPES, UserType } from '@pom/types/user-type';

export class LoginPO {
  private readonly acceptCookiesButton: Locator;
  private readonly welcomeText: Locator;
  private readonly mainContent: Locator;
  private readonly emailInput: Locator;
  private readonly passwordInput: Locator;
  private readonly signInButton: Locator;
  private readonly welcomeTitle: Locator;

  constructor(private page: Page) {
    this.acceptCookiesButton = page.locator('#cookie_consent_display button:has-text("Accept")');
    this.welcomeText = page.locator('#main-content');
    this.mainContent = page.locator('#main-content');
    this.emailInput = page.locator('#login_form_email');
    this.passwordInput = page.locator('#login_form_password');
    this.signInButton = page.locator('#login_form button:has-text("Sign in")');
    this.welcomeTitle = page.locator('main h1');
  }

  async acceptCookies() {
    await this.acceptCookiesButton.waitFor({ state: 'visible' });
    await this.acceptCookiesButton.click();
  }

  async verifyTitle(expectedTitle: string) {
    await expect(this.page).toHaveTitle(expectedTitle);
  }

  async verifyWelcomeText(expectedText: string) {
    await expect(this.welcomeText).toContainText(expectedText);
  }

  async verifyRole(expectedRole: string) {
    await expect(this.mainContent).toContainText(expectedRole);
  }

  async fillEmail(email: string) {
    await this.emailInput.click();
    await this.emailInput.clear();
    await this.emailInput.fill(email);
  }

  async fillPassword(password: string) {
    await this.passwordInput.click();
    await this.passwordInput.clear();
    await this.passwordInput.fill(password);
  }

  async clickSignInButton() {
    await this.signInButton.click();
  }

  async selectRoleAccount(role: UserType) {
    const navbarco = new NavbarCO(this.page);

    if (role === USER_TYPES.STUDENT) {
      await navbarco.clickLogo();
    }
    if (role === USER_TYPES.INSTRUCTOR) {
      await navbarco.goToInstructorsLogin();
    }
    if (role === USER_TYPES.AUTHOR) {
      await navbarco.goToAuthorsLogin();
    }
  }

  async verifyWelcomeTitle(expectedTitle: string) {
    await expect(this.welcomeTitle).toContainText(expectedTitle);
  }
}
