import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class CurriculumPO {
  private readonly basicPracticeButton: Locator;
  private readonly basicScoredButton: Locator;
  private readonly editPageLink: Locator;
  private readonly deleteButton: Locator;
  private readonly confirmDeleteButton: Locator;
  private readonly creationSectionButton: Locator;
  private readonly createUnitButton: Locator;
  private readonly unitLink: Locator;
  private readonly createModuleButton: Locator;
  private readonly moduleLink: Locator;
  private readonly dropdown: Locator;

  constructor(private readonly page: Page) {
    this.basicPracticeButton = page.getByRole('button', { name: 'Practice' }).first();
    this.basicScoredButton = page.getByRole('button', { name: 'Scored' }).first();
    this.createUnitButton = page.getByRole('button', { name: 'Create a Unit' });
    this.createModuleButton = page.getByRole('button', { name: 'Create a Module' });
    this.confirmDeleteButton = page.getByRole('button', { name: 'Delete Page' });
    this.creationSectionButton = page.getByRole('button', { name: 'Create a Section' });
    this.editPageLink = page.getByRole('link', { name: 'Edit Page' });
    this.unitLink = page.getByRole('link', { name: 'Unit 1: Unit' });
    this.moduleLink = page.getByRole('link', { name: 'Module 1: Module' });
    this.deleteButton = page.locator('button[role="show_delete_modal"]');
    this.dropdown = page.locator('button.btn.dropdown-toggle');
  }

  async clickBasicPracticeButton() {
    await this.basicPracticeButton.click();
    await this.verifyPage();
  }

  async clickBasicScoredButton() {
    await this.basicScoredButton.click();
    await this.verifyPage('New Assessment');
  }

  async clickCreateUnitButton() {
    await this.createUnitButton.click();
    await Verifier.expectIsVisible(this.unitLink);
  }

  async clickCreateModuleButton() {
    await this.createModuleButton.click();
    await Verifier.expectIsVisible(this.moduleLink);
  }

  async clickEditPageLink(name = 'New Page', edit = 'Edit Page') {
    const link = this.createLocatorPage(name, edit);
    await link.locator(this.editPageLink).click();
  }

  async clickEditUnitLink(name = 'Unit 1: Unit') {
    const l = this.page.getByRole('link', { name });
    await l.click();
    await Verifier.expectIsVisible(this.createModuleButton);
  }

  async clickEditModuleLink() {
    await this.moduleLink.click();
    await Verifier.expectIsVisible(this.creationSectionButton);
  }

  async deletePage(name = 'New Page', edit = 'Edit Page') {
    const page = this.createLocatorPage(name, edit);
    const dropdown = page.locator(this.dropdown);
    const deleteButton = page.locator(this.deleteButton);

    await Verifier.expectIsVisible(dropdown);
    await dropdown.click();
    await deleteButton.click();
    await Verifier.expectIsVisible(this.confirmDeleteButton);
    await this.confirmDeleteButton.click();
    await Verifier.expectIsHidden(page);
  }

  async hasContent(text: string) {
    const l = this.page.getByText(text);
    await Verifier.expectIsVisible(l);
  }

  private async verifyPage(name = 'New Page', edit = 'Edit Page') {
    const l = this.createLocatorPage(name, edit);
    await Verifier.expectIsVisible(l);
  }

  private createLocatorPage(name: string, edit: string) {
    return this.page
      .locator('div.curriculum-entry')
      .filter({ has: this.page.locator(`span:has-text("${name}")`) })
      .filter({ has: this.page.locator(`a:has-text("${edit}")`) });
  }
}
