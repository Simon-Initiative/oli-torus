import { Locator, Page, expect } from '@playwright/test';
import { NavbarCO } from './NavbarCO';
import { Utils } from '../../../../core/Utils';
import { USER_TYPES, UserType } from '../types/user-type';

export class LoginPO {
  private acceptCookiesButton: Locator;
  private welcomeText: Locator;
  private mainContent: Locator;
  private emailInput: Locator;
  private passwordInput: Locator;
  private signInButton: Locator;

  constructor(private page: Page) {
    this.acceptCookiesButton = page.getByRole('button', { name: 'Accept' });
    this.welcomeText = page.locator('#main-content');
    this.mainContent = page.locator('#main-content');
    this.emailInput = page.getByRole('textbox', { name: 'Email' });
    this.passwordInput = page.getByRole('textbox', { name: 'Password' });
    this.signInButton = page.getByRole('button', { name: 'Sign in' });
  }

  async acceptCookies() {
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
    await new Utils(this.page).sleep(2);
    await this.emailInput.click();
    await this.emailInput.fill(email);
  }

  async fillPassword(password: string) {
    await this.passwordInput.click();
    await this.passwordInput.fill(password);
  }

  async clickSignInButton() {
    await this.signInButton.click();
  }


  async selectRoleAccount(role: UserType) {
    const navbarco = new NavbarCO(this.page);

    if (role === USER_TYPES.STUDENT) {
      await navbarco.selectStudentLogin();
    } else if (role === USER_TYPES.INSTRUCTOR) {
      await navbarco.selectInstructorLogin();
    } else if (role === USER_TYPES.AUTHOR) {
      await navbarco.selectCourseAuthorLogin();
    } else if (role === USER_TYPES.ADMIN) {
      await navbarco.selectAdministratorLogin();
    }
  }
}
