import { Page } from "@playwright/test";
import { LoginPO } from "../pom/login/LoginPO";
import { WorkspaceStudentPO } from "../pom/workspace/student/WorkspaceStudentPO";
import { WorkspaceInstructorPO } from "../pom/workspace/instructor/WorkspaceInstructorPO";
import { WorkspaceAuthorPO } from "../pom/workspace/author/WorkspaceAuthorPO";
import { AuthorDashboardPO } from "../pom/workspace/author/AuthorDashboardPO";
import { Utils } from "../../../core/Utils";
import { OverviewProjectPO } from "../pom/workspace/author/OverviewProjectPO";
import { PublishProjectPO } from "../pom/workspace/author/PublishProjectPO";
import { AuthorSidebarCO } from "../pom/workspace/author/AuthorSidebarCO";
import { InstructorDashboardPO } from "../pom/workspace/instructor/InstructorDashboardPO";
import { NewCourseSetupPO } from "../pom/workspace/instructor/NewCourseSetupPO";

export class TorusFacade {
  private page: Page;
  private environment: string;
  private utils: Utils;
  private loginpo: LoginPO;
  private wss: WorkspaceStudentPO;
  private wsi: WorkspaceInstructorPO;
  private wsa: WorkspaceAuthorPO;
  private instructorDashboard: InstructorDashboardPO;

  constructor(page: Page, environment: string) {
    this.page = page;
    this.environment = environment;
    this.utils = new Utils(this.page);
    this.loginpo = new LoginPO(this.page);
    this.wss = new WorkspaceStudentPO(this.page);
    this.wsi = new WorkspaceInstructorPO(this.page);
    this.wsa = new WorkspaceAuthorPO(this.page);
    this.instructorDashboard = new InstructorDashboardPO(this.page);
  }

  async goToSite() {
    await this.page.goto(this.environment);
  }

  async closeSite() {
    await this.page.close();
  }

  async login(
    role: "student" | "instructor" | "author",
    pageTitleVerify: string,
    roleVerify: string,
    welcomeTextVerify: string,
    email: string,
    password: string,
    headerVerify: string,
    coockies: boolean = true
  ) {
    if (coockies) await this.loginpo.acceptCookies();
    await this.loginpo.selectRoleAccount(role);
    await this.loginpo.verifyTitle(pageTitleVerify);
    await this.loginpo.verifyRole(roleVerify);
    await this.loginpo.verifyWelcomeText(welcomeTextVerify);
    await this.loginpo.fillEmail(email);
    await this.loginpo.fillPassword(password);
    await this.loginpo.clickSignInButton();
    if (role === "student") await this.wss.verifyName(headerVerify);
    if (role === "instructor") await this.wsi.verifyrHeader(headerVerify);
    if (role === "author") await this.wsa.verifyHeader(headerVerify);
  }

  async createNewProjectAsOpen(projectNameFilter: string) {
    let projectName: string = "";
    await this.wsa.getAuthorDashboard().searchProject(projectNameFilter);
    const lastProject = await this.wsa.getAuthorDashboard().getLastProjectName();

    if (lastProject) projectName = await this.utils.incrementID(lastProject);
    else projectName = projectNameFilter;

    await this.wsa.getAuthorDashboard().clickNewProjectButton();
    await this.wsa.getAuthorDashboard().fillProjectName(projectName);
    await this.wsa.getAuthorDashboard().clickCreateButton();
    await this.wsa.getOverviewProject().waitForEditorReady();
    await this.wsa.getOverviewProject().setVisibilityOpen();
    await this.wsa.getAuthorSidebar().publishProject();
    await this.wsa.getPublishProject().clickPublishButton();
    await this.wsa.getPublishProject().clickOkButton();
    return projectName;
  }

  async verifyProjectAsOpen(projectName: string) {
    await this.instructorDashboard.clickCreateNewSection();
    await this.wsa.getNewCourseSetup().searchProject(projectName);
    await this.wsa.getNewCourseSetup().verifySearchResult(projectName);
  }
}
