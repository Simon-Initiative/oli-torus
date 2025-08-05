import { TorusFacade } from "@facade/TorusFacade";
import test from "@playwright/test";
import { TestData } from "../test-data";
import { NewCourseSetupPO } from "@pom/course/NewCourseSetupPO";
import { DetailsCourseSetupPO } from "@pom/project/DetailsCourseSetupPO";
import { OverviewProjectPO } from "@pom/project/OverviewProjectPO";
import { LearningLanguageType, LicenseOptionType } from "@pom/types/project-attributes-types";
import { AuthorDashboardPO } from "@pom/workspace/author/AuthorDashboardPO";
import { SidebarCO } from "@pom/component/SidebarCO";
import { CurriculumPO } from "@pom/project/CurriculumPO";
import { BasicPracticePagePO } from "@pom/page/BasicPracticePagePO";
import { ActivityType } from "@pom/types/activity-types";
import { Utils } from "@core/Utils";

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

  test('Log in as an author and create a new course project with valid details, set the Publishing Visibility as Open', async ({
    page,
  }) => {
    const startDate = new Date();
    const endDate = new Date(new Date());
    endDate.setFullYear(endDate.getFullYear() + 1);

    await torus.login(loginData.author.type);
    const projectName = await torus.createNewProjectAsOpen(testData.projectNameFilter);
    await torus.goToSite();
    await torus.login(loginData.instructor.type);
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

  test('Edit project attributes (description, license, etc) with valid details', async ({
    page,
  }) => {
    const overview = new OverviewProjectPO(page);
    const courseId = 'tqa10automation';
    const course = `${testData.baseUrl}/workspaces/course_author/${courseId}/overview`;
    const languageValue: LearningLanguageType = 'be';
    const licenseValue: LicenseOptionType = 'cc_by';

    await torus.login(loginData.author.type);
    await torus.goToSite(course);

    await overview.projectAttributes.selectLearningLanguage(languageValue);
    await overview.projectAttributes.selectLicense(licenseValue);
    await overview.projectAttributes.clickSave();
    await overview.projectAttributes.expectSelectedValues(languageValue, licenseValue);
  });

  test('In the project overiew, enable activities, go to the curriculum, add a page, and verify the enabled activities can be added to the page', async ({
    page,
  }) => {
    const overiew = new OverviewProjectPO(page);
    const authorDashboardPO = new AuthorDashboardPO(page);
    const sidebar = new SidebarCO(page);
    const curriculum = new CurriculumPO(page);
    const practiceNewPage = new BasicPracticePagePO(page);
    const nameProject = 'TQA-11-Automation';
    const projectId = 'tqa11automation';
    const pageOverview = `${testData.baseUrl}/workspaces/course_author/${projectId}/overview`;
    const activities: ActivityType[] = [
      'logic_lab',
      'adaptive',
      'dnd',
      'dd',
      'coding',
      'file_aupload',
      'hotspot',
      'likert',
      'multi',
      'embed',
      'response_multi',
      'vlab',
    ];

    await torus.login(loginData.author.type);
    await authorDashboardPO.search.fillSearchInput(nameProject);
    await authorDashboardPO.table.clickProjectLink(nameProject);

    for (const activity of activities) {
      await overiew.advancedActivities.clickEnableAllActivities(projectId, activity);
    }

    await sidebar.author.clickCreate();
    await sidebar.author.clickCurriculum();
    await curriculum.create.clickBasicPracticeButton();
    await curriculum.create.clickEditPageLink();
    await practiceNewPage.visibleTitlePage();

    for (const activity of activities) {
      await new Utils(page).scrollToTop();
      await new Utils(page).sleep();
      await practiceNewPage.clickInsertButtonIcon();
      await practiceNewPage.selectActivity(activity);
      await practiceNewPage.waitForChangesSaved();
    }

    await practiceNewPage.waitForChangesSaved();
    await new Utils(page).sleep(2);
    await torus.reloadPage();
    await practiceNewPage.visibleTitlePage();

    for (const activity of activities) {
      await practiceNewPage.expectActivityVisible(activity);
    }

    await sidebar.author.clickCurriculum();
    await curriculum.delete.openPageDropdownMenu();
    await curriculum.delete.clickShowDeleteModalButton();
    await curriculum.delete.confirmDeletePage();
    await torus.goToSite(pageOverview);

    for (const activity of activities) {
      await overiew.advancedActivities.clickDisableAllActivities(projectId, activity);
    }
  });

  test('Modify text, add an image, and change text formatting in an existing BASIC page.', async ({
    page,
  }) => {
    const practiceNewPage = new BasicPracticePagePO(page);
    const curriculum = new CurriculumPO(page);
    const courseId = 'tqa12automation';
    const course = `${testData.baseUrl}/workspaces/course_author/${courseId}/curriculum`;
    const paragraphText = 'Text generated by automation';
    const newParagraphText = 'New text generated by automation';
    const imageFileName = 'img-mock-05-16-2025.jpg';

    await torus.login(loginData.author.type);
    await torus.goToSite(course);
    await curriculum.create.clickEditPageLink();
    await practiceNewPage.visibleTitlePage();
    await practiceNewPage.deleteAllActivities();
    await torus.reloadPage();
    await practiceNewPage.fillParagraph(paragraphText);
    await practiceNewPage.waitForChangesSaved();
    await torus.reloadPage();
    await practiceNewPage.fillParagraph(newParagraphText);
    await practiceNewPage.selectElementToolbar('Format');
    await practiceNewPage.selectElementToolbar('List');
    await practiceNewPage.clickParagraph(2);
    await practiceNewPage.selectElementToolbar('Insert Image');
    const selectImage = await practiceNewPage.clickChoseImage();
    await selectImage.waitForLabel('Select Image');
    await selectImage.selectMediaByName(imageFileName);
    await selectImage.confirmSelection();
    await torus.reloadPage();
    await practiceNewPage.visibleTitlePage();
    await practiceNewPage.expectImage(imageFileName);
    await practiceNewPage.expectText(newParagraphText, 1);
  });
});