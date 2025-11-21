import { Verifier } from '@core/verify/Verifier';
import { Page } from '@playwright/test';

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
    const bl = this.createLocator(role, name);
    await Verifier.expectIsVisible(bl);
    await bl.click();
  }

  private async visiblekByRole(role: 'button' | 'link', name: SidebarButtonName | SidebarLinkName) {
    const bl = this.createLocator(role, name);
    return await bl.isVisible();
  }

  private createLocator(role: 'button' | 'link', name: SidebarButtonName | SidebarLinkName) {
    if (name === 'PublishBTN') name = 'Publish';
    return this.page.getByRole(role, { name, exact: true });
  }
}
