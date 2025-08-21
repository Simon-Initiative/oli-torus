import { Utils } from '@core/Utils';
import { Locator, Page, expect } from '@playwright/test';

export class CurriculumPO {
  private utils: Utils;
  private basicPracticeButton: Locator;
  private basicScoredButton: Locator;
  private editPageLink: Locator;
  private pageDropdownToggle: Locator;
  private showDeleteModalButton: Locator;
  private confirmDeleteButton: Locator;
  private createUnitButton: Locator;
  private unitLink: Locator;
  private createModuleButton: Locator;
  private firstPracticeButton: Locator;
  private moduleLink: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(page);
    this.basicPracticeButton = this.page.getByRole('button', { name: 'Practice' }).first();
    this.basicScoredButton = this.page.getByRole('button', { name: 'Scored' }).first();
    this.editPageLink = this.page.getByRole('link', { name: 'Edit Page' });
    this.pageDropdownToggle = this.page.locator('div.dropdown>button.btn.dropdown-toggle').first();
    this.showDeleteModalButton = this.page.locator('button[role="show_delete_modal"]').first();
    this.confirmDeleteButton = this.page.getByRole('button', { name: 'Delete Page' });
    this.createUnitButton = this.page.getByRole('button', { name: 'Create a Unit' });
    this.unitLink = this.page.getByRole('link', { name: 'Unit 1: Unit' });
    this.createModuleButton = this.page.getByRole('button', { name: 'Create a Module' });
    this.firstPracticeButton = this.page.getByRole('button', { name: 'Practice' }).first();
    this.moduleLink = this.page.getByRole('link', { name: 'Module 1: Module' });
  }

  private async clickPracticeButton() {
    await expect(this.basicPracticeButton).toBeVisible();
    await this.basicPracticeButton.click();
  }

  get create() {
    return {
      clickBasicPracticeButton: async () => await this.clickPracticeButton(),
      clickBasicScoredButton: async () => await this.basicScoredButton.click(),
      clickEditPageLink: async () => await this.editPageLink.click(),

      unit: {
        add: async () => {
          await this.utils.sleep(1);
          await expect(this.createUnitButton).toBeVisible();
          await this.createUnitButton.click();

          await expect(this.unitLink).toBeVisible();
        },
        open: async () => {
          await expect(this.unitLink).toBeVisible();
          await this.unitLink.click();
          await this.utils.sleep();
        },
        addPracticePage: async () => {
          await this.clickPracticeButton();
        },
      },

      module: {
        add: async () => {
          await expect(this.createModuleButton).toBeVisible();
          await this.createModuleButton.click();
          await this.utils.sleep();
        },
        open: async () => {
          await expect(this.moduleLink).toBeVisible();
          await this.moduleLink.click();
          await this.utils.sleep();
        },
        addPracticePage: async () => {
          await this.clickPracticeButton();
        },
      },

      practicePage: {
        add: async () => {
          await this.clickPracticeButton();
        },
      },
    };
  }

  get delete() {
    return {
      openPageDropdownMenu: async () => {
        await this.pageDropdownToggle.click();
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
      unitIsVisible: async () => {
        await expect(this.unitLink).toBeVisible();
      },
      moduleIsVisible: async () => {
        await expect(this.moduleLink).toBeVisible();
      },
      practicePageIsVisible: async () => {
        await expect(this.basicPracticeButton).toBeVisible();
      },
    };
  }
}
