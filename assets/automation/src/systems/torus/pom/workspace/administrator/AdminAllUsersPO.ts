import { Page, Locator } from '@playwright/test';
import { Utils } from '@core/Utils';

export class AdminAllUsersPO {
  private utils: Utils;
  private searchInput: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(this.page);
    this.searchInput = this.page.locator('#text-search-input');
  }

  async searchUser(text: string) {
    await this.utils.writeWithDelay(this.searchInput, text);
  }

  async openUserDetails(name: string) {
    await this.page.getByRole('link', { name: name }).click();
  }
}
