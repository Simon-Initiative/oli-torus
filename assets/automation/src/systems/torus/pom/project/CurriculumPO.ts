import { Locator, Page, expect } from '@playwright/test';

export class CurriculumPO {
  private readonly basicPracticeButton: Locator;
  private readonly basicScoredButton: Locator;
  private readonly editPageLink: Locator;
  private readonly dropdown: Locator;
  private readonly showDeleteModalButton: Locator;
  private readonly confirmDeleteButton: Locator;
  private readonly createUnitButton: Locator;
  private readonly unitLink: Locator;
  private readonly createModuleButton: Locator;
  private readonly moduleLink: Locator;

  constructor(private page: Page) {
    this.basicPracticeButton = this.page.getByRole('button', { name: 'Practice' }).first();
    this.basicScoredButton = this.page.getByRole('button', { name: 'Scored' }).first();
    this.editPageLink = this.page.getByRole('link', { name: 'Edit Page' });
    this.dropdown = this.page.locator('div.dropdown>button.btn.dropdown-toggle').first();
    this.showDeleteModalButton = this.page.locator('button[role="show_delete_modal"]').first();
    this.confirmDeleteButton = this.page.getByRole('button', { name: 'Delete Page' });
    this.createUnitButton = this.page.getByRole('button', { name: 'Create a Unit' });
    this.unitLink = this.page.getByRole('link', { name: 'Unit 1: Unit' });
    this.createModuleButton = this.page.getByRole('button', { name: 'Create a Module' });
    this.moduleLink = this.page.getByRole('link', { name: 'Module 1: Module' });
  }

  async clickBasicPracticeButton() {
    await this.basicPracticeButton.click();
    await expect(this.editPageLink).toBeVisible();
  }

  async clickBasicScoredButton() {
    await this.basicScoredButton.click();
  }

  async clickCreateUnitButton() {
    await this.createUnitButton.click();
    await expect(this.unitLink).toBeVisible();
  }

  async clickCreateModuleButton() {
    await this.createModuleButton.click();
    await expect(this.moduleLink).toBeVisible();
  }

  async clickEditPageLink() {
    await this.editPageLink.click();
  }

  async clickEditUnitLink() {
    await this.unitLink.click();
  }

  async clickEditModuleLink() {
    await this.moduleLink.click();
  }

  async openDropdown() {
    await this.dropdown.click();
  }

  get delete() {
    return {
      openPageDropdownMenu: async () => {
        await this.dropdown.click();
      },
      clickShowDeleteModalButton: async () => {
        await this.showDeleteModalButton.click();
      },
      confirmDeletePage: async () => {
        await this.confirmDeleteButton.click();
      },
    };
  }

  get verify() {
    return {
      practicePageIsVisible: async () => {
        await expect(this.basicPracticeButton).toBeVisible();
      },
    };
  }
}
