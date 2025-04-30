import { Page, Locator, expect } from "@playwright/test";
import { Utils } from "../../../../../core/Utils";

export class AdminUserDetailsPO {
  private page: Page;
  private utils: Utils;
  private editButton: Locator;
  private checkBox: Locator;
  private saveButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.utils = new Utils(this.page);
    this.editButton = this.page.getByRole("button", { name: "Edit" });
    this.checkBox = this.page.getByRole("checkbox", {
      name: "Can Create Sections",
    });
    this.saveButton = this.page.getByRole("button", { name: "Save" });
  }

  async clickEditButton() {
    await this.utils.forceClick(this.editButton, this.saveButton);
  }

  async checkCreateSections() {
    await this.checkBox.check();
  }

  async clickSaveButton() {
    await this.utils.forceClick(this.saveButton, this.editButton);
  }
}
