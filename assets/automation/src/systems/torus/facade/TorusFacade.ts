import { Page } from '@playwright/test';
import { LoginPO } from '../pom/login/LoginPO';
import { USER_TYPES, UserType } from '../pom/types/user-type';
import { Utils } from '../../../core/Utils';
import { WorkspaceAuthorPO } from '../pom/workspace/author/WorkspaceAuthorPO';
import { WorkspaceInstructorPO } from '../pom/workspace/instructor/WorkspaceInstructorPO';
import { WorkspaceStudentPO } from '../pom/workspace/student/WorkspaceStudentPO';

export class TorusFacade {
  private page: Page;
  private environment: string;
  private utils: Utils;
  private loginpo: LoginPO;
  private wss: WorkspaceStudentPO;
  private wsi: WorkspaceInstructorPO;
  private wsa: WorkspaceAuthorPO;

  constructor(page: Page, environment?: string) {
    this.page = page;
    this.environment = environment ?? '/';
    this.utils = new Utils(this.page);
    this.loginpo = new LoginPO(this.page);
    this.wss = new WorkspaceStudentPO(this.page);
    this.wsi = new WorkspaceInstructorPO(this.page);
    this.wsa = new WorkspaceAuthorPO(this.page);
  }

  async goToSite(environment: string = this.environment) {
    await this.page.goto(environment);
  }

  async closeSite() {
    await this.page.close();
  }

  async login(
    role: UserType,
    pageTitleVerify: string,
    roleVerify: string,
    welcomeTextVerify: string,
    email: string = 'missing email',
    password: string = 'missing password',
    headerVerify: string,
    coockies: boolean = true,
  ) {
    if (coockies) {
      await this.utils.sleep(2);
      await this.loginpo.acceptCookies();
    }
    await this.loginpo.selectRoleAccount(role);
    await this.page.waitForLoadState();
    await this.loginpo.verifyTitle(pageTitleVerify);
    await this.loginpo.verifyRole(roleVerify);
    await this.loginpo.verifyWelcomeText(welcomeTextVerify);
    await this.loginpo.fillEmail(email);
    await this.loginpo.fillPassword(password);
    await this.loginpo.clickSignInButton();
    if (role === USER_TYPES.STUDENT) await this.wss.verifyName(headerVerify);
    if (role === USER_TYPES.INSTRUCTOR) await this.wsi.verifyrHeader(headerVerify);
    if (role === USER_TYPES.AUTHOR) await this.wsa.verifyHeader(headerVerify);
    if (role === USER_TYPES.ADMIN) await this.wsa.verifyHeader(headerVerify);
  }
}
