import { Locator, Page } from '@playwright/test';

export class NavbarCO {
  private readonly logoLinkNavbar: Locator;
  private readonly logoLinkHeader: Locator;
  private readonly instructorsLink: Locator;
  private readonly authorsLink: Locator;
  private readonly supportLink: Locator;

  constructor(page: Page) {
    this.logoLinkNavbar = page.locator('nav  a.navbar-brand');
    this.logoLinkHeader = page.locator('#header_logo_button');
    this.instructorsLink = page.getByRole('link', { name: 'For Instructors' });
    this.authorsLink = page.getByRole('link', { name: 'For Course Authors' });
    this.supportLink = page.locator('#tech_support_navbar_sign_in');
  }

  async clickLogo() {
    try {
      await this.logoLinkNavbar.click();
    } catch {
      await this.logoLinkHeader.click();
    }
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
}
