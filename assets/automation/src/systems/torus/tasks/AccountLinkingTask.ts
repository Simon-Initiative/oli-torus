import { step } from '@core/decoration/step';
import { AccountLinkingPO } from '@pom/home/AccountLinkingPO';
import { MenuDropdownCO } from '@pom/home/MenuDropdownCO';
import { Page } from '@playwright/test';

export class AccountLinkingTask {
  private readonly accountLinking: AccountLinkingPO;
  private readonly menu: MenuDropdownCO;

  constructor(private readonly page: Page) {
    this.accountLinking = new AccountLinkingPO(page);
    this.menu = new MenuDropdownCO(page);
  }

  @step('Open account linking from the delivery account menu')
  async openFromAccountMenu() {
    await this.menu.open();
    await this.menu.goToLinkAuthoringAccount();
  }

  @step('Attempt to link authoring account {email}')
  async link(email: string, password: string) {
    await this.accountLinking.link(email, password);
  }

  @step('Verify invalid authoring credentials are rejected')
  async verifyInvalidCredentials() {
    await this.accountLinking.expectInvalidCredentials();
  }

  @step('Verify the authoring account was linked')
  async verifyLinkSucceeded() {
    await this.accountLinking.expectLinkSucceeded();
  }

  @step('Verify linked authoring account {email} in the delivery account menu')
  async verifyLinkedAccountInMenu(email: string) {
    await this.menu.open();
    await this.menu.expectLinkedAuthoringAccount(email);
  }

  @step('Verify another account cannot be linked while {email} is linked')
  async verifyDuplicateLinkPrevented(email: string) {
    await this.page.goto('/users/link_account');
    await this.accountLinking.expectAlreadyLinked(email);
  }
}
