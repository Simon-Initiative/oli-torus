import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export type SidebarButtonName =
  | 'Minimize'
  | 'Expand'
  | 'Create'
  | 'PublishBTN'
  | 'Improve'
  | 'Support';

export type SidebarLinkName =
  | 'Course Author'
  | 'Instructor'
  | 'Student'
  | 'Overview'
  | 'Objectives'
  | 'Activity Bank'
  | 'Experiments'
  | 'Bibliography'
  | 'Curriculum'
  | 'All Pages'
  | 'All Activities'
  | 'Review'
  | 'Publish'
  | 'Products'
  | 'Templates'
  | 'Insights'
  | 'Datasets'
  | 'Home'
  | 'Learn'
  | 'Schedule'
  | 'Assignments'
  | 'Exit Course'
  | 'Exit Project';

export class SidebarCO {
  private readonly buttonNames = new Set<SidebarButtonName>([
    'Minimize',
    'Expand',
    'Create',
    'PublishBTN',
    'Improve',
    'Support',
  ]);

  constructor(private readonly page: Page) {}

  async clickInMenu(name: SidebarButtonName | SidebarLinkName) {
    const isButton = this.buttonNames.has(name as SidebarButtonName);

    if (isButton) {
      await this.clickByRole('button', name);
    } else {
      await this.clickByRole('link', name);
    }
  }

  async isVisible(name: SidebarButtonName | SidebarLinkName) {
    const isButton = this.buttonNames.has(name as SidebarButtonName);

    if (isButton) {
      return await this.visiblekByRole('button', name);
    } else {
      return await this.visiblekByRole('link', name);
    }
  }

  private async clickByRole(role: 'button' | 'link', name: SidebarButtonName | SidebarLinkName) {
    const bl = await this.createLocator(role, name);
    await Verifier.expectIsVisible(bl);
    await bl.click();
  }

  private async visiblekByRole(role: 'button' | 'link', name: SidebarButtonName | SidebarLinkName) {
    const bl = await this.createLocator(role, name);
    return await bl.isVisible();
  }

  private async createLocator(role: 'button' | 'link', name: SidebarButtonName | SidebarLinkName) {
    const names = this.aliasesFor(name);

    for (const sidebar of this.sidebarCandidates()) {
      if (!(await sidebar.isVisible().catch(() => false))) continue;

      for (const sidebarName of names) {
        const item = sidebar.getByRole(role, { name: sidebarName, exact: true });
        if ((await item.count().catch(() => 0)) > 0) return item;
      }
    }

    return this.sidebarCandidates()[0].getByRole(role, { name: names[0], exact: true });
  }

  private aliasesFor(
    name: SidebarButtonName | SidebarLinkName,
  ): (SidebarButtonName | SidebarLinkName)[] {
    if (name === 'PublishBTN') return ['Publish'];
    if (name === 'Products' || name === 'Templates') return ['Templates', 'Products'];

    return [name];
  }

  private sidebarCandidates(): Locator[] {
    return [
      this.page.locator('#desktop-workspace-nav-menu').first(),
      this.page.locator('#desktop-nav-menu').first(),
      this.page.locator('#mobile-nav-menu').first(),
    ];
  }
}
