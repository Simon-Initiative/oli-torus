import { Page } from '@playwright/test';
import { LoginPO } from '../pom/login/LoginPO';
import { WorkspaceStudentPO } from '../pom/workspace/student/WorkspaceStudentPO';
import { WorkspaceInstructorPO } from '../pom/workspace/instructor/WorkspaceInstructorPO';
import { WorkspaceAuthorPO } from '../pom/workspace/author/WorkspaceAuthorPO';
import { Utils } from '../../../core/Utils';
import { MenuCO } from '../pom/menu/MenuCO';
import { AdminManagementPO } from '../pom/workspace/administrator/AdminManagementPO';
import { AdminAllUsersPO } from '../pom/workspace/administrator/AdminAllUsersPO';
import { AdminUserDetailsPO } from '../pom/workspace/administrator/AdminUserDetailsPO';
import { USER_TYPES, UserType } from '../pom/types/user-type';

export class TorusFacade {
  private environment: string;
  private utils: Utils;
  private loginpo: LoginPO;
  private menu: MenuCO;
  private wss: WorkspaceStudentPO;
  private wsi: WorkspaceInstructorPO;
  private wsa: WorkspaceAuthorPO;
  private adminManagment: AdminManagementPO;
  private adminAllUsers: AdminAllUsersPO;
  private adminUserDetails: AdminUserDetailsPO;

  constructor(private page: Page, environment?: string) {
    this.environment = environment ?? '/';
    this.utils = new Utils(this.page);
    this.loginpo = new LoginPO(this.page);
    this.menu = new MenuCO(this.page);
    this.wss = new WorkspaceStudentPO(this.page);
    this.wsi = new WorkspaceInstructorPO(this.page);
    this.wsa = new WorkspaceAuthorPO(this.page);
    this.adminManagment = new AdminManagementPO(this.page);
    this.adminAllUsers = new AdminAllUsersPO(this.page);
    this.adminUserDetails = new AdminUserDetailsPO(this.page);
  }

  async goToSite(environment: string = this.environment) {
    await this.page.goto(environment);
  }

  async closeSite() {
    await this.page.close();
  }

  async reloadPage() {
    await this.page.reload();
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

  async createNewProjectAsOpen(projectNameFilter: string) {
    let projectName: string = '';
    await this.wsa.getDashboard().searchProject(projectNameFilter);
    // await this.wsa.getDashboard().sortByCreatedDescending();
    const lastProject = await this.wsa.getDashboard().getLastProjectName();

    if (lastProject) projectName = await this.utils.incrementID(lastProject);
    else projectName = projectNameFilter;

    await this.wsa.getDashboard().clickNewProjectButton();
    await this.wsa.getDashboard().fillProjectName(projectName);
    await this.wsa.getDashboard().clickCreateButton();
    await this.wsa.getOverviewProject().waitForEditorReady();
    await this.wsa.getOverviewProject().setVisibilityOpen();
    await this.wsa.getSidebar().clickPublishProject();
    await this.wsa.getSidebar().clickPublishLink();
    await this.wsa.getPublishProject().clickPublishButton();
    await this.wsa.getPublishProject().clickOkButton();
    return projectName;
  }

  // async openLatestCreatedProject(baseName: string = 'AutomationProject') {
  //   await this.wsa.getDashboard().searchProject(baseName);
  //   await this.wsa.getDashboard().sortByCreatedDescending();

  //   const lastProject = await this.wsa.getDashboard().getLastProjectName();

  //   let projectName: string;
  //   if (lastProject) {
  //     projectName = this.utils.incrementID(lastProject);
  //   } else {
  //     projectName = baseName;
  //   }

  //   await this.wsa.getDashboard().clickNewProjectButton();
  //   await this.wsa.getDashboard().fillProjectName(projectName);
  //   await this.wsa.getDashboard().clickCreateButton();
  //   await this.wsa.getOverviewProject().waitForEditorReady();
  //   await this.wsa.getOverviewProject().setVisibilityOpen();
  //   await this.wsa.getSidebar().clickPublishProject();
  //   await this.wsa.getSidebar().clickPublishLink();
  //   await this.wsa.getPublishProject().clickPublishButton();
  //   await this.wsa.getPublishProject().clickOkButton();

  //   return projectName;
  // }

  async verifyProjectAsOpen(projectName: string) {
    await this.wsi.getDashboard().clickCreateNewSection();
    await this.wsi.getNewCourseSetup().searchProject(projectName);
    await this.wsi.getNewCourseSetup().verifySearchResult(projectName);
  }

  async canCreateSections(searchEmail: string, nameLink: string) {
    await this.menu.openMenu();
    await this.menu.clickAdminPanel();
    await this.adminManagment.goToManageStudents();
    await this.adminAllUsers.searchUserByEmail(searchEmail);
    await this.adminAllUsers.openUserDetails(nameLink);
    await this.adminUserDetails.clickEditButton();
    await this.adminUserDetails.checkCreateSections();
    await this.adminUserDetails.clickSaveButton();
    await this.menu.openUserAccountMenu();
    await this.menu.clickSignOut();
  }

  async verifyCanCreateSections(textToVerify: string) {
    await this.wss.getStudentSidebar().clickInstructorLink();
    await this.wsi.getDashboard().clickCreateNewSection();
    await this.wsi.getNewCourseSetup().verifyTextStepperContent(textToVerify);
  }
}
