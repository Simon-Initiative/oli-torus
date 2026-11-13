import { step } from '@core/decoration/step';
import { expect, Locator, Page } from '@playwright/test';

export type MobileCourseNavLink = 'Home' | 'Learn' | 'Notes' | 'Explorations';

const NAV_LINK_IDS: Record<MobileCourseNavLink, string> = {
  Home: '#mobile_home_nav_link',
  Learn: '#mobile_learn_nav_link',
  Notes: '#mobile_discussions_nav_link',
  Explorations: '#mobile_explorations_nav_link',
};

/**
 * The hamburger menu that replaces the course sidebar below the md breakpoint. It also
 * holds the only user account menu available on course pages at phone width.
 */
export class MobileCourseNavCO {
  private readonly openButton: Locator;
  private readonly menu: Locator;
  private readonly closeButton: Locator;
  private readonly userMenuButton: Locator;

  constructor(private readonly page: Page) {
    this.openButton = page.locator('#mobile-nav-open');
    this.menu = page.locator('#mobile-nav-menu');
    // The header covers the panel's own Close button, so the menu closes from the header.
    this.closeButton = page.locator('#mobile-nav-close');
    this.userMenuButton = this.menu.locator('#mobile-user-account-menu-sidebar');
  }

  @step('Open the mobile course menu')
  async open() {
    // The menu toggles through LiveView JS commands, which only run once the view is connected.
    await expect(this.page.locator('[data-phx-main]')).toHaveClass(/phx-connected/);
    await expect(async () => {
      await this.openButton.click();
      await expect(this.menu).toBeVisible({ timeout: 2_000 });
    }).toPass({ timeout: 15_000 });
  }

  /** Also dismisses the user menu, which closes on any click outside it. */
  @step('Close the mobile course menu')
  async close() {
    await this.closeButton.click();
    await expect(this.menu).toBeHidden();
    await expect(this.openButton).toBeVisible();
  }

  @step('Go to {link} from the mobile course menu')
  async goTo(link: MobileCourseNavLink) {
    await this.open();
    const navLink = this.menu.locator(NAV_LINK_IDS[link]);
    await expect(navLink).toBeVisible();
    await navLink.click();
  }

  @step('Open the user menu from the mobile course menu')
  async openUserMenu() {
    await this.open();
    await this.userMenuButton.click();
    await expect(this.page.locator('#mobile-user-account-menu-sidebar-dropdown')).toBeVisible();
  }

  @step('Go to Account Settings from the mobile course menu')
  async goToAccountSettings() {
    await this.open();
    await Promise.all([
      this.page.waitForURL((url) => url.pathname === '/users/settings'),
      this.menu.getByRole('link', { name: 'Settings', exact: true }).click(),
    ]);
  }

  @step('Expect the mobile course menu to show the user name {name}')
  async expectUserName(name: string) {
    await this.open();
    // The footer shows the name next to the avatar; the closed user menu repeats it hidden.
    await expect(
      this.menu.getByText(name, { exact: true }).filter({ visible: true }),
    ).toBeVisible();
    await this.close();
  }
}
