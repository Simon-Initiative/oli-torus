import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class MenuDropdownCO {
  private readonly menuButton: Locator;
  private readonly menuButtonAdmin: Locator;
  private readonly workspaceMenu: Locator;
  private readonly adminPanelLink: Locator;
  private readonly signOutLink: Locator;

  constructor(page: Page) {
    this.menuButton = page.locator('#workspace-user-menu');
    this.menuButtonAdmin = page.locator('#user-account-menu');
    this.workspaceMenu = page.locator('#workspace-user-menu-dropdown');
    this.adminPanelLink = this.workspaceMenu.getByRole('link', { name: 'Admin Panel' });
    this.signOutLink = page.getByRole('link', { name: 'Sign out' });
  }

  async open(isAdminScreen = false) {
    if (isAdminScreen) {
      await this.menuButtonAdmin.click();
    } else {
      await this.menuButton.click();
    }
  }

  async goToAdminPanel() {
    await this.adminPanelLink.click();
  }

  async signOut() {
    try {
      await Waiter.waitFor(this.workspaceMenu, 'attached');
      await this.workspaceMenu.locator(this.signOutLink).click();
    } catch {
      await this.signOutLink.click();
      console.log(
        '%o menu not found. Try with %o',
        this.signOutLink,
        this.workspaceMenu.locator(this.signOutLink),
      );
    }
  }
}
