import { expect, Locator, Page } from '@playwright/test';

// How the associated list labels each kind of record.
export type AssociationType = 'Project' | 'Template';

/**
 * Admin community pages: the Manage Communities list, a community overview, and its
 * associated Projects and Templates list with the "Add new +" picker.
 */
export class CommunityPO {
  private readonly associationsTable: Locator;

  constructor(private readonly page: Page) {
    this.associationsTable = this.page.locator('#projects-products-table');
  }

  // Both the community list and the "Add new" picker label their search "Search communities".
  async search(text: string) {
    await this.waitForLiveView();
    await this.page.getByRole('textbox', { name: 'Search communities', exact: true }).fill(text);
    await this.page.getByRole('button', { name: 'Search', exact: true }).click();
    await expect(this.rowWith(text)).toBeVisible();
  }

  async openCommunityOverview(name: string) {
    await this.rowWith(name).getByRole('link', { name: 'Overview', exact: true }).click();
    await expect(this.page).toHaveURL(/\/authoring\/communities\/\d+$/);
  }

  async openAssociated() {
    await this.page.getByRole('link', { name: 'See associated', exact: true }).click();
    await expect(this.page).toHaveURL(/\/authoring\/communities\/\d+\/associated$/);
  }

  async openAddNew() {
    await this.page.getByRole('link', { name: 'Add new +', exact: true }).click();
    await expect(this.page).toHaveURL(/\/authoring\/communities\/\d+\/associated\/new/);
  }

  async select(title: string, type: AssociationType) {
    // The confirmation flash calls templates by their internal name, "product".
    const flashType = type === 'Template' ? 'product' : 'project';

    await this.waitForLiveView();
    await this.rowWith(title).getByRole('button', { name: 'Select', exact: true }).click();
    await expect(
      this.page.getByText(`Association to ${flashType} successfully added.`, { exact: true }),
    ).toBeVisible();
  }

  async backToAssociated() {
    await this.page
      .getByRole('navigation', { name: 'breadcrumb' })
      .getByRole('link', { name: 'Associated', exact: true })
      .click();
    await expect(this.page).toHaveURL(/\/authoring\/communities\/\d+\/associated$/);
  }

  async expectAssociatedOnce(title: string, type: AssociationType) {
    const rows = this.associationsTable
      .getByRole('row')
      .filter({ has: this.page.getByRole('link', { name: title, exact: true }) });

    await expect(rows).toHaveCount(1);
    await expect(rows.getByRole('cell', { name: type, exact: true })).toBeVisible();
  }

  async openAssociatedLink(title: string) {
    await this.associationsTable.getByRole('link', { name: title, exact: true }).click();
  }

  // Projects open their authoring overview; templates open their product details page.
  async expectRecordOpened(title: string, type: AssociationType, slug: string) {
    const [path, titleLabel] =
      type === 'Project'
        ? [`/workspaces/course_author/${slug}/overview`, 'Project Title']
        : [`/authoring/products/${slug}`, 'Title'];

    await expect(this.page).toHaveURL(new RegExp(`${path}$`));
    await expect(this.page.getByLabel(titleLabel, { exact: true })).toHaveValue(title);
  }

  // Clicks that land before the LiveView connects are dropped.
  private async waitForLiveView() {
    await expect(this.page.locator('[data-phx-main]')).toHaveClass(/phx-connected/);
  }

  private rowWith(text: string) {
    return this.page.getByRole('row').filter({ hasText: text });
  }
}
