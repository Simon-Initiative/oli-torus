import { Page } from '@playwright/test';
import { MenuDropdownCO } from '@pom/home/MenuDropdownCO';
import { LoginPO } from '@pom/home/LoginPO';
import { TypeUser } from '@pom/types/type-user';
import { TestData } from 'tests/torus/test-data';
import { SidebarCO } from '@pom/home/SidebarCO';
import { Waiter } from '@core/wait/Waiter';
import { Utils } from '@core/Utils';
import { step } from '@core/decoration/step';

export class HomeTask {
  private readonly utils: Utils;
  private readonly testData: TestData;
  private readonly loginpo: LoginPO;
  private readonly menu: MenuDropdownCO;
  private readonly sidebar: SidebarCO;

  constructor(
    private readonly page: Page,
    private readonly environment = '/',
  ) {
    this.utils = new Utils(page);
    this.loginpo = new LoginPO(page);
    this.testData = new TestData();
    this.menu = new MenuDropdownCO(page);
    this.sidebar = new SidebarCO(page);
  }

  async goToSite(environment = this.environment) {
    await this.page.goto(environment);
  }

  async closeSite() {
    await this.page.close();
  }

  @step('Login as {role}')
  async login(role: TypeUser) {
    const dataUser = this.testData.loginData[role];

    await this.loginpo.acceptCookies();
    await this.utils.modalDisappears();
    await this.loginpo.selectRoleAccount(dataUser.type);
    await Waiter.waitForLoadState(this.page);
    await this.loginpo.verifyTitle(dataUser.pageTitle);
    await this.loginpo.verifyRole(dataUser.role);
    await this.loginpo.verifyWelcomeText(dataUser.welcomeText);
    await this.loginpo.fillEmail(dataUser.email);
    await this.loginpo.fillPassword(dataUser.pass);
    await this.loginpo.clickSignInButton();
    await this.loginpo.verifyWelcomeTitle(dataUser.welcomeTitle);

    if (role === 'administrator') {
      await this.dismissFlashMessages();
    }
  }

  @step('Logout')
  async logout(isAdminScreen = false) {
    await this.menu.open(isAdminScreen);
    await this.menu.signOut();
  }

  @step('Enter to Curriculum')
  async enterToCurriculum() {
    const visible = await this.sidebar.isVisible('Curriculum');

    if (!visible) {
      await this.sidebar.clickInMenu('Create');
    }
    await this.sidebar.clickInMenu('Curriculum');
  }

  @step('Enter to Course Author')
  async enterToCourseAuthor() {
    await this.sidebar.clickInMenu('Course Author');
  }

  @step('Enter to Overview')
  async enterToOverview() {
    await this.sidebar.clickInMenu('Overview');
  }

  @step('Enter to Publish')
  async enterToPublish() {
    const visible = await this.sidebar.isVisible('Publish');

    if (!visible) {
      await this.sidebar.clickInMenu('PublishBTN');
    }
    await this.sidebar.clickInMenu('Publish');
  }

  @step('Enter to Learn')
  async enterToLearn() {
    await this.sidebar.clickInMenu('Learn');
  }

  @step('Enter to Products')
  async enterToProducts() {
    await this.sidebar.clickInMenu('Products');
  }

  @step('Login as {role} {variable1} {variable2} {varialbe3} {variable4}')
  async probando(
    role: TypeUser,
    variable1: string,
    variable2 = 'hola',
    varialbe3 = 1,
    variable4?: string,
  ) {
    console.log('algo');
  }

  private async dismissFlashMessages() {
    const possibleFlash = this.page
      .locator(
        '#live_flash_container [role="alert"], #live_flash_container .alert, .alert[role="alert"], .alert-info, .alert-danger',
      )
      .first();

    for (let attempts = 0; attempts < 3; attempts += 1) {
      try {
        await possibleFlash.waitFor({ state: 'visible', timeout: 2000 });
      } catch {
        break;
      }

      const isVisible = await possibleFlash.isVisible().catch(() => false);

      if (!isVisible) {
        break;
      }

      const closeButton = possibleFlash
        .locator('button[aria-label="Close"], button.close, [data-bs-dismiss="alert"]')
        .first();

      if ((await closeButton.count()) > 0) {
        await closeButton.click();
      } else {
        await possibleFlash.evaluate((node) => node.remove());
      }

      try {
        await Waiter.waitFor(possibleFlash, 'hidden');
      } catch {
        const hidden = await possibleFlash.waitFor({ state: 'hidden', timeout: 1000 }).catch(() => undefined);

        if (!hidden) {
          break;
        }
      }
    }
  }
}
