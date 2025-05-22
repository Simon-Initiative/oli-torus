import { Page, Locator } from "@playwright/test";
import { Utils } from "../../../../../core/Utils";

export class AdminAllUsersPO {
  private page: Page;
  private utils: Utils;
  private searchInput: Locator;

  constructor(page: Page) {
    this.page = page;
    this.utils = new Utils(this.page);
    this.searchInput = this.page.locator("#text-search-input");
  }

  async searchUser(user: string) {
    await this.searchInput.click();
    await this.utils.sleep(1);
    await this.searchInput.pressSequentially(user);
    await this.utils.sleep(1);
  }

  async clickNameLink(name: string) {
    await this.page.getByRole("link", { name: `${name}` }).click();
  }
}
