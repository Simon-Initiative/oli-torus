import { Utils } from '@core/Utils';
import { Locator, Page } from '@playwright/test';

export class CurriculumPO {
  private utils: Utils;
  private basicPracticeButton: Locator;
  private basicScoredButton: Locator;
  private editPageLink: Locator;
  private pageDropdownToggle: Locator;
  private showDeleteModalButton: Locator;
  private confirmDeleteButton: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(page);
    this.basicPracticeButton = this.page
      .getByRole('button', {
        name: 'Practice',
      })
      .first();
    this.basicScoredButton = this.page
      .getByRole('button', {
        name: 'Scored',
      })
      .first();
    this.editPageLink = this.page.getByRole('link', { name: 'Edit Page' });
    this.pageDropdownToggle = this.page.locator('div.dropdown>button.btn.dropdown-toggle').first();
    this.showDeleteModalButton = this.page.locator('button[role="show_delete_modal"]').first();
    this.confirmDeleteButton = this.page.getByRole('button', { name: 'Delete Page' });
  }

  get create() {
    return {
      clickBasicPracticeButton: async () => await this.basicPracticeButton.click(),
      clickBasicScoredButton: async () => await this.basicScoredButton.click(),
      clickEditPageLink: async () => await this.editPageLink.click(),
    };
  }

  get delete() {
    return {
      openPageDropdownMenu: async () => {
        await this.pageDropdownToggle.click();
        await this.utils.sleep();
      },

      clickShowDeleteModalButton: async () => {
        await this.showDeleteModalButton.click();
        await this.utils.sleep();
      },

      confirmDeletePage: async () => {
        await this.confirmDeleteButton.click();
        await this.utils.sleep();
      },
    };
  }
}
