import { expect, Page } from '@playwright/test';
import { MenuDropdownCO } from '@pom/home/MenuDropdownCO';
import { AdminDashboardPO } from '@pom/dashboard/AdminDashboardPO';
import { step } from '@core/decoration/step';

export class AdministrationTask {
  private readonly menu: MenuDropdownCO;
  private readonly adminP: AdminDashboardPO;

  constructor(private readonly page: Page) {
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

  @step('As an administrator, open the author account {email}')
  async openAuthor(email: string) {
    await this.page.goto(`/admin/authors?text_search=${encodeURIComponent(email)}`);
    await this.adminP.openResultWithText(email, 'Author, Test');
  }

  @step("Change the opened author's system role to {role}")
  async changeSystemRole(role: string) {
    await this.adminP.startEdit();
    await this.adminP.selectSystemRole(role);
    await this.adminP.clickInButton('Save');
    await this.adminP.expectFlash('Author successfully updated.');
    await this.page.reload();
    await this.adminP.expectSystemRole(role);
  }

  @step("Verify the opened author's system role cannot be edited")
  async verifySystemRoleLocked() {
    await this.adminP.startEdit();
    await this.adminP.expectSystemRoleLocked();
  }

  @step('Verify {path} redirects a non-admin author away')
  async verifyAdminPageDenied(path: string) {
    await this.page.goto(path);
    await expect(this.page).toHaveURL(/\/workspaces\/course_author$/);
    await this.adminP.expectFlash('You are not authorized to access this page.');
  }

  @step('Verify the system-admin audit log is reachable')
  async verifyAuditLogReachable() {
    await this.page.goto('/admin/audit_log');
    await expect(this.page).toHaveURL(/\/admin\/audit_log$/);
    await expect(this.page.locator('select[name="event_type"]')).toBeVisible();
  }
}
