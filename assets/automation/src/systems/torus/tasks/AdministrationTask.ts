import { Page } from '@playwright/test';
import { MenuDropdownCO } from '@pom/home/MenuDropdownCO';
import { AdminDashboardPO } from '@pom/dashboard/AdminDashboardPO';
import { step } from '@core/decoration/step';

export class AdministrationTask {
  private readonly menu: MenuDropdownCO;
  private readonly adminP: AdminDashboardPO;

  constructor(page: Page) {
    this.menu = new MenuDropdownCO(page);
    this.adminP = new AdminDashboardPO(page);
  }

  /**
   * Allow user to create section
   * @param searchEmail - The email address used to search for the user in the admin panel.
   * @param nameLink - The visible name of the user link in the search results.
   * @returns A Promise that resolves when the operation is completed.
   */
  @step(
    "As an administrator, access a user's profile to configure the 'Can Create Sections' field.",
  )
  async canCreateSections(searchEmail: string, nameLink: string) {
    await this.menu.open();
    await this.menu.goToAdminPanel();
    await this.adminP.clickInAccess('Manage Students and Instructor Accounts');
    await this.adminP.search(searchEmail);
    await this.adminP.openResult(nameLink);
    await this.adminP.clickInButton('Edit');
    await this.adminP.clickInCheckbox('Can Create Sections');
    await this.adminP.clickInButton('Save');
  }
}
