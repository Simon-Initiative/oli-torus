import { Locator, Page } from '@playwright/test';

export class NavbarCO {
  private readonly logoLinkNavbar: Locator;
  private readonly logoLinkHeader: Locator;
  private readonly instructorsLink: Locator;
  private readonly authorsLink: Locator;
  private readonly supportLink: Locator;
  private readonly administratorLink: Locator;

  constructor(page: Page) {
    this.logoLinkNavbar = page.locator('nav  a.navbar-brand');
    this.logoLinkHeader = page.locator('#header_logo_button');
    this.authorsLink = page.getByRole('link', { name: 'For Course Authors' });
    this.supportLink = page.getByRole('link', { name: 'Support' });
    this.administratorLink = page.getByRole('link', { name: 'Administrator' });
  }

  async clickLogo() {
    try {
      await this.logoLinkNavbar.click({ timeout: 10_000 });
    } catch {
      await this.logoLinkHeader.click({ timeout: 10_000 });
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

  async goToAdministratorLogin() {
    await this.administratorLink.click();
  }
}
