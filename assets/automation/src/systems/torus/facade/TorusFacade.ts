import { Utils } from '@core/Utils';
import { Page } from '@playwright/test'; 
import { MenuDropdownCO } from '@pom/component/MenuDropdownCO';
import { LoginPO } from '@pom/login/LoginPO';
import { USER_TYPES, UserType } from '@pom/types/user-type';
import { AdminAllUsersPO } from '@pom/workspace/administrator/AdminAllUsersPO';
import { AdminUserDetailsPO } from '@pom/workspace/administrator/AdminUserDetailsPO';
import { WorkspaceAuthorPO } from '@pom/workspace/author/WorkspaceAuthorPO';
import { WorkspaceInstructorPO } from '@pom/workspace/instructor/WorkspaceInstructorPO';
import { WorkspaceStudentPO } from '@pom/workspace/student/WorkspaceStudentPO';

export class TorusFacade {
  private environment: string;
  private utils: Utils;
  private loginpo: LoginPO;
  private menu: MenuDropdownCO;
  private wss: WorkspaceStudentPO;
  private wsi: WorkspaceInstructorPO;
  private wsa: WorkspaceAuthorPO;
  private adminAllUsers: AdminAllUsersPO;
  private adminUserDetails: AdminUserDetailsPO;

  constructor(private page: Page, environment?: string) {
    this.environment = environment ?? '/';
    this.utils = new Utils(this.page);
    this.loginpo = new LoginPO(this.page);
    this.menu = new MenuDropdownCO(this.page);
    this.wss = new WorkspaceStudentPO(this.page);
    this.wsi = new WorkspaceInstructorPO(this.page);
    this.wsa = new WorkspaceAuthorPO(this.page);
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
    await this.wsa.dashboard.search.fillSearchInput(projectNameFilter);
    const lastProject = await this.wsa.dashboard.table.getLastProjectName();

    if (lastProject) projectName = await this.utils.incrementID(lastProject);
    else projectName = projectNameFilter;

    await this.wsa.dashboard.new.clickNewProjectButton();
    await this.wsa.dashboard.new.fillProjectName(projectName);
    await this.wsa.dashboard.new.clickCreateButton();
    await this.wsa.overviewProject.details.waitForEditorReady();
    await this.wsa.overviewProject.publishingVisibility.setVisibilityOpen();
    await this.wsa.sidebar.author.clickPublish();
    await this.wsa.sidebar.author.clickPublishLink();
    await this.wsa.publishProject.clickPublishButton();
    await this.wsa.publishProject.clickOkButton();
    return projectName;
  }

  async verifyProjectAsOpen(projectName: string) {
    await this.wsi.dashboard.clickCreateNewSection();
    await this.wsi.newCourseSetup.step1.searchProject(projectName);
    await this.wsi.newCourseSetup.step1.verifySearchResult(projectName);
  }

  async canCreateSections(searchEmail: string, nameLink: string) {
    await this.goToSite('/admin/users');
    await this.adminAllUsers.searchUserByEmail(searchEmail);
    await this.adminAllUsers.openUserDetails(nameLink);
    await this.adminUserDetails.clickEditButton();
    await this.adminUserDetails.checkCreateSections();
    await this.adminUserDetails.clickSaveButton();
    await this.goToSite('/workspaces/course_author');
    await this.menu.open();
    await this.menu.signOut();
  }

  async verifyCanCreateSections(textToVerify: string) {
    await this.wss.sidebar.workspace.clickInstructor();
    await this.wsi.dashboard.clickCreateNewSection();
    await this.wsi.newCourseSetup.step1.verifyTextStepperContent(textToVerify);
  }

  async deletePage(projectName: string) {
    const s = this.wsa.dashboard.search;
    const t = this.wsa.dashboard.table;
    const a = this.wsa.sidebar.author;
    const d = this.wsa.curriculum.delete;

    await s.fillSearchInput(projectName);
    await t.clickProjectLink(projectName);
    await a.clickCreate();
    await a.clickCurriculum();
    await d.openPageDropdownMenu();
    await d.clickShowDeleteModalButton();
    await d.confirmDeletePage();
  }

  async addPage(type: 'basic-practice' | 'basic-scored', projectName: string) {
    const s = this.wsa.dashboard.search;
    const t = this.wsa.dashboard.table;
    const a = this.wsa.sidebar.author;
    const c = this.wsa.curriculum.create;

    await s.fillSearchInput(projectName);
    await t.clickProjectLink(projectName);
    await this.utils.sleep();
    await a.clickCreate();
    await this.utils.sleep();
    await a.clickCurriculum();
    await this.utils.sleep();

    if (type === 'basic-practice') await c.clickBasicPracticeButton();
    if (type === 'basic-scored') await c.clickBasicScoredButton();
  }
}
