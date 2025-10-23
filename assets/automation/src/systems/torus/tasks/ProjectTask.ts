import { Utils } from '@core/Utils';
import { Page } from '@playwright/test';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';
import { OverviewProjectPO } from '@pom/project/OverviewProjectPO';
import { PublishProjectPO } from '@pom/project/PublishProjectPO';
import { AuthorDashboardPO } from '@pom/dashboard/AuthorDashboardPO';
import { InstructorDashboardPO } from '@pom/dashboard/InstructorDashboardPO';
import { newCS_CantResults, newCS_Filter, newCS_Title } from './data/data-project-task';
import { TypeLanguage } from '@pom/types/types-language';
import { TypeLicenseOption } from '@pom/types/type-license-options';
import { step } from '@core/decoration/step';

export class ProjectTask {
  private readonly authorDB: AuthorDashboardPO;
  private readonly instructorDB: InstructorDashboardPO;
  private readonly overviewP: OverviewProjectPO;
  private readonly publishP: PublishProjectPO;
  private readonly newCS: NewCourseSetupPO;
  private readonly utils: Utils;

  constructor(private readonly page: Page) {
    this.authorDB = new AuthorDashboardPO(page);
    this.instructorDB = new InstructorDashboardPO(page);
    this.overviewP = new OverviewProjectPO(page);
    this.publishP = new PublishProjectPO(page);
    this.newCS = new NewCourseSetupPO(page);
    this.utils = new Utils(page);
  }

  @step("Search and enter the project '{projectName}'")
  async searchAndEnterProject(projectName: string) {
    await this.authorDB.searchProject(projectName);
    await this.authorDB.clickProjectLink(projectName);
    await this.overviewP.details.waitForEditorReady();
  }

  async createNewProjectAsOpen(projectName: string) {
    await this.authorDB.clickNewProjectButton();
    await this.authorDB.fillProjectName(projectName);
    await this.authorDB.clickCreateButton();
    await this.overviewP.details.waitForEditorReady();
    const projectID = await this.overviewP.details.getProjectID();
    await this.overviewP.publishingVisibility.setVisibilityOpen();

    return { projectName, projectID };
  }

  async filterAndReturnProjectCreated(projectName: string) {
    await this.authorDB.searchProject(projectName);
    await this.authorDB.sortByTitleDescending();
    const lastProject = await this.authorDB.getFirstRowTable();

    if (lastProject.length > 0) return lastProject[0];
    else return projectName;
  }

  @step("Evalute if project '{projectName}' exist")
  async projectExist(projectName: string) {
    await this.authorDB.searchProject(projectName);
    const rows = await this.authorDB.getAllRowsTable();

    for (const row of rows) {
      if (row[0] === projectName) return true;
    }

    return false;
  }

  @step("Verify project '{projectName}' as open")
  async verifyProjectAsOpen(projectName: string, numberResults = 1) {
    await this.instructorDB.clickCreateNewSection();
    await this.newCS.verify(newCS_Title);
    await this.newCS.step1.searchProject(projectName);
    const nr = this.utils.format(newCS_CantResults, '{}', numberResults.toString());
    await this.newCS.verify(`${newCS_Filter} "${projectName}"`);
    await this.newCS.verify(nr);
  }

  async publishProject(description?: string) {
    if (description) await this.publishP.fillDescription(description);
    await this.publishP.clickPublish();
    await this.publishP.clickOk();
    await this.utils.modalDisappears();
  }

  async configureProjectAttributes(languageValue: TypeLanguage, licenseValue: TypeLicenseOption) {
    await this.overviewP.projectAttributes.selectLearningLanguage(languageValue);
    await this.overviewP.projectAttributes.selectLicense(licenseValue);
    await this.overviewP.projectAttributes.clickSave();
    await this.overviewP.projectAttributes.expectSelectedValues(languageValue, licenseValue);
  }
}
