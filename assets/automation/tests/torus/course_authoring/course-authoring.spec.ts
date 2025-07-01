import { TorusFacade } from "@facade/TorusFacade";
import test from "@playwright/test";
import { TestData } from "../test-data";
import { NewCourseSetupPO } from "@pom/course/NewCourseSetupPO";
import { DetailsCourseSetupPO } from "@pom/project/DetailsCourseSetupPO";

const testData = new TestData();
const loginData = testData.loginData;
let torus: TorusFacade;

test.describe('Course authoring', () => {
  test.beforeEach(async ({ page }) => {
    torus = new TorusFacade(page);
    await torus.goToSite();
  });

  test.afterEach(async () => {
    await torus.closeSite();
  });

  test('TQA9-Log in as an author and create a new course project with valid details, set the Publishing Visibility as Open', async ({
    page,
  }) => {
    const startDate = new Date();
    const endDate = new Date(new Date());
    endDate.setFullYear(endDate.getFullYear() + 1);

    await torus.login(
      loginData.author.type,
      loginData.author.pageTitle,
      loginData.author.role,
      loginData.author.welcomeText,
      loginData.author.email,
      loginData.author.pass,
      loginData.author.header,
    );

    const projectName = await torus.createNewProjectAsOpen(testData.projectNameFilter);

    await torus.goToSite();
    await torus.login(
      loginData.intructor.type,
      loginData.intructor.pageTitle,
      loginData.intructor.role,
      loginData.intructor.welcomeText,
      loginData.intructor.email,
      loginData.intructor.pass,
      loginData.intructor.header,
    );

    await torus.verifyProjectAsOpen(projectName);

    const courseSetup = new NewCourseSetupPO(page);
    const detailCourse = new DetailsCourseSetupPO(page);

    await courseSetup.step1.searchProject(projectName);
    await courseSetup.step1.verifySearchResult(projectName);
    await courseSetup.step1.verifyTextStepperContent('Showing all results (1 total)');

    await courseSetup.step2.clickOnCardProject(projectName);
    await courseSetup.step2.fillCourseName(projectName);
    await courseSetup.step2.fillCourseSectionNumber(projectName);
    await courseSetup.step2.goToNextStep();

    await courseSetup.step3.fillStartDate(startDate);
    await courseSetup.step3.fillEndDate(endDate);
    await courseSetup.step3.submitSection();
    await detailCourse.verifyBreadcrumbTrail(projectName);
    await detailCourse.verifyCourseSectionID(projectName);
    await detailCourse.verifyTitle(projectName);
    await detailCourse.verifyUrl(testData.baseUrl, projectName);
  });
});