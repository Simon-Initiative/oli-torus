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
import { ProductsPO } from '@pom/product/ProductsPO';
import { ProductOverviewPO } from '@pom/product/ProductOverviewPO';
import { Waiter } from '@core/wait/Waiter';
import { Verifier } from '@core/verify/Verifier';

export class ProjectTask {
  private readonly authorDB: AuthorDashboardPO;
  private readonly instructorDB: InstructorDashboardPO;
  public readonly overviewP: OverviewProjectPO;
  private readonly publishP: PublishProjectPO;
  private readonly newCS: NewCourseSetupPO;
  private readonly products: ProductsPO;
  private readonly productOverview: ProductOverviewPO;
  private readonly utils: Utils;

  constructor(private readonly page: Page) {
    this.authorDB = new AuthorDashboardPO(page);
    this.instructorDB = new InstructorDashboardPO(page);
    this.overviewP = new OverviewProjectPO(page);
    this.publishP = new PublishProjectPO(page);
    this.newCS = new NewCourseSetupPO(page);
    this.products = new ProductsPO(page);
    this.productOverview = new ProductOverviewPO(page);
    this.utils = new Utils(page);
  }

  @step("Search and enter the project '{projectName}'")
  async searchAndEnterProject(projectName: string) {
    await this.authorDB.searchProject(projectName);
    await this.authorDB.clickProjectLink(projectName);
    await this.overviewP.details.waitForEditorReady();
  }

  @step("Create a new project '{projectName}' as open")
  async createNewProjectAsOpen(projectName: string) {
    await this.authorDB.clickNewProjectButton();
    await this.authorDB.fillProjectName(projectName);
    await this.authorDB.clickCreateButton();
    await this.overviewP.details.waitForEditorReady();
    const projectID = await this.overviewP.details.getProjectID();
    await this.overviewP.publishingVisibility.setVisibilityOpen();

    return { projectName, projectID };
  }

  @step("Filter project by name '{projectName}' and return the last result")
  async filterAndReturnProject(projectName: string) {
    await this.authorDB.searchProject(projectName);
    await this.authorDB.sortByTitleDescending();
    const lastProject = await this.authorDB.getFirstRowTable();

    if (lastProject?.length > 0) return lastProject[0];
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

  @step('Publish project')
  async publishProject(description?: string) {
    if (description) {
      await this.publishP.fillDescription(description);
    }

    const autoPush = await this.publishP.autoPushIsChecked();
    if (!autoPush && autoPush != null) {
      await this.publishP.clickAutoPush();
    }
    await this.publishP.clickPublish();
    await this.publishP.clickOk();
    await this.utils.modalDisappears();
  }

  @step('Configure project attributes. Language: {languageValue}, License: {licenseValue}')
  async configureProjectAttributes(languageValue: TypeLanguage, licenseValue: TypeLicenseOption) {
    await this.overviewP.projectAttributes.selectLearningLanguage(languageValue);
    await this.overviewP.projectAttributes.selectLicense(licenseValue);
    await this.overviewP.projectAttributes.clickSave();
    await this.overviewP.projectAttributes.expectSelectedValues(languageValue, licenseValue);
  }

  @step('Ceate the product "{projectName}" and open it')
  async createAndOpenProduct(projectName: string) {
    await this.products.waitingToBeCentered();
    const { productName, productId } = await this.products.createProduct(projectName);
    await this.products.openProduct(productName);
    await this.productOverview.details.waitForEditorReady();
    await this.productOverview.verifyHeader();
    await this.productOverview.verifyProductTitle(productName);
    return { productName, productId };
  }

  @step('Add a bibliography to the project name')
  async addBibliographyToProject(bibliography: string) {
    await Waiter.waitFor(this.page.locator('#content > div.mx-auto'), 'visible');
    await this.page.getByRole('button', { name: 'Add Entry', exact: true }).click();
    await Waiter.waitFor(
      this.page.getByRole('heading', { level: 5, name: 'Create Entry' }),
      'visible',
    );
    await this.page.locator('div.modal-body>div>textarea').fill(bibliography);
    await this.page.locator('div.modal-footer').getByRole('button', { name: 'Create' }).click();
    await Verifier.expectIsVisible(
      this.page.getByText('Showing result 1 - 1 of 1').first(),
      'visible',
    );
  }
}
