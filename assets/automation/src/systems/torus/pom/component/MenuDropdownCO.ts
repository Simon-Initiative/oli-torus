import { Locator, Page } from '@playwright/test';

export class MenuDropdownCO {
  private readonly menuButton: Locator;
  private readonly workspaceMenu: Locator;
  private readonly rol: Locator;
  private readonly adminPanelLink: Locator;
  private readonly editAccountLink: Locator;
  private readonly myCoursesLink: Locator;
  private readonly timezoneSelect: Locator;
  private readonly researchConsentLink: Locator;
  private readonly emailLink: Locator;
  private readonly signOutLink: Locator;
  private readonly userMenuButton: Locator;

  constructor(page: Page) {
    this.menuButton = page.locator('#workspace-user-menu');
    this.workspaceMenu = page.locator('#workspace-user-menu-dropdown');
    this.rol = this.workspaceMenu.locator('role="account label"');
    this.adminPanelLink = this.workspaceMenu.getByRole('link', { name: 'Admin Panel' });
    this.editAccountLink = this.workspaceMenu.getByRole('link', { name: 'Edit Account' });
    this.myCoursesLink = this.workspaceMenu.getByRole('link', { name: 'My Courses' });
    this.timezoneSelect = this.workspaceMenu.locator('select[name="timezone[timezone]"]');
    this.researchConsentLink = this.workspaceMenu.getByRole('link', { name: 'Research Consent' });
    this.emailLink = this.workspaceMenu.locator('a>div[role="linked authoring account email"]');
    this.signOutLink = this.workspaceMenu.getByRole('link', { name: 'Sign out' });
    this.userMenuButton = page.locator('#user-account-menu');
    this.signOutLink = page.locator('a[href="/users/log_out"]');
  }

  async open() {
    await this.menuButton.click();
  }

  async getRole() {
    return await this.rol.innerText();
  }

  async goToAdminPanel() {
    await this.adminPanelLink.click();
  }

  async goToEditAccount() {
    await this.editAccountLink.click();
  }

  async goToMyCourses() {
    await this.myCoursesLink.click();
  }

  async selectTimezone(value: string) {
    await this.timezoneSelect.selectOption(value);
  }

  async goToResearchConsent() {
    await this.researchConsentLink.click();
  }

  async getLinkedAccountEmail() {
    return this.emailLink.click();
  }

  async signOut() {
    await this.signOutLink.click();
  }

  async selectTheme(type: string) {
    const themeLocator = this.workspaceMenu.locator(`label[for="${type}"]`);
    await themeLocator.click();
  }

  async openUserMenu() {
    await this.userMenuButton.click();
  }
}
