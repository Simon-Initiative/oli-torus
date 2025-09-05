import { Locator, Page } from '@playwright/test';

export class NavbarCO {
  private readonly logoLink: Locator;
  private readonly instructorsLink: Locator;
  private readonly authorsLink: Locator;
  private readonly supportLink: Locator;
  private readonly administratorLink: Locator;

  constructor(page: Page) {
    this.logoLink = page.locator('a.navbar-brand');
    this.instructorsLink = page.getByRole('link', { name: 'For Instructors' });
    this.authorsLink = page.getByRole('link', { name: 'For Course Authors' });
    this.supportLink = page.getByRole('link', { name: 'Support' });
    this.administratorLink = page.getByRole('link', { name: 'Administrator' });
  }

  async clickLogo() {
    await this.logoLink.click();
  }

  async goToInstructorsLogin() {
    await this.instructorsLink.click();
  }

  async goToAuthorsLogin() {
    await this.authorsLink.click();
  }

  async openSupportModal() {
    await this.supportLink.click();
  }

  async goToAdministratorLogin() {
    await this.administratorLink.click();
  }
}
