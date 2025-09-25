import test from '@playwright/test';
import { TorusFacade } from '@facade/TorusFacade';
import { SidebarCO } from '@pom/component/SidebarCO';
import { CurriculumPO } from '@pom/project/CurriculumPO';
import { ActivityType, ACTIVITY_TYPE } from '@pom/types/activity-types';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';
import { CourseManagePO } from '@pom/course/CourseManagePO';
import { Utils } from '@core/Utils';
import { OverviewProjectPO } from '@pom/project/OverviewProjectPO';
import { BasicPracticePagePO } from '@pom/page/BasicPracticePagePO';
import { TestData } from '../test-data';
import { BasicScoredPagePO } from '@pom/page/BasicScoredPagePO';
import { VlabCO } from '@pom/component/activities/VlabCO';
import { DdCO } from '@pom/component/activities/DdCO';
import { ResponseCO } from '@pom/component/activities/ResponseCO';
import { MultiCO } from '@pom/component/activities/MultiCO';
import { LikertCO } from '@pom/component/activities/LikertCO';
import { DndCO } from '@pom/component/activities/DndCO';
import { FileUploadCO } from '@pom/component/activities/FileUploadCO';
import { CodingCO } from '@pom/component/activities/CodingCO';
import { HotspotCO } from '@pom/component/activities/HotspotCO';
import { LearningLanguageType, LicenseOptionType } from '@pom/types/project-attributes-types';

const testData = new TestData();
const loginData = testData.loginData;
const questionText = 'Question test?';
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
    const detailCourse = new CourseManagePO(page);
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
    await detailCourse.assertions.verifyBreadcrumbTrail(projectName);
    await detailCourse.assertions.verifyCourseSectionID(projectName);
    await detailCourse.assertions.verifyTitle(projectName);
    await detailCourse.assertions.verifyUrl(testData.baseUrl, projectName);
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

  test.describe('Enable and verify one activity per test', () => {
    const projectName = 'TQA-11-Automation';
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

    for (const activity of activities) {
      const label = ACTIVITY_TYPE[activity].label;
      test(label, async () => {
        await torus.login(loginData.author.type);
        await torus.goToSite(pageOverview);
        await torus.project().overview.enableActivity(projectId, activity);
        await torus.sidebar().clickCourseAuthor();
        await torus.project().addPageAndEnter('basic-practice', projectName);
        await torus.project().page.activity.add(activity);
        await torus.sidebar().clickCourseAuthor();
        await torus.project().deletePage(projectName);
        await torus.goToSite(pageOverview);
        await torus.project().overview.disableActivity(projectId, activity);
      });
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
    await curriculum.clickEditPageLink();
    await practiceNewPage.verifyTitlePage();
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
    await practiceNewPage.verifyTitlePage();
    await practiceNewPage.expectImage(imageFileName);
    await practiceNewPage.expectText(newParagraphText, 1);
  });

  test.describe('TQA-13 - Add one of each type of content to a new page', () => {
    const nameProject = 'TQA-13-Automation';
    const typePage = 'basic-practice';

    test('TQA-13-Cite', async () => {
      const citation = {
        name: 'Newton, I.',
        id: 'philosophi_naturalis_principia',
        text: 'Newton, I. (2025). “Philosophiæ naturalis principia mathematica.”',
      };

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addCiteVerify(citation.name, citation.id, citation.text);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Foreign', async () => {
      const language = 'arabic';
      const paragraphText = 'Text generated by automation';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addForeignVerify(paragraphText, language);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Image', async () => {
      const imageName = 'img-mock-05-16-2025.jpg';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addImageVerify(imageName);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Formula', async () => {
      const formula = '1+2=3';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addFormulaVerify(formula);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Callout', async () => {
      const paragraphText =
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addCalloutVerify(paragraphText);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-PopUp', async () => {
      const paragraphText = 'Text generated by automation';
      const popupText = 'Popup text';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addPopUpVerify(paragraphText, popupText);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Dialog', async () => {
      const dialogTitle = "This is a dialog's title";
      const dialogSpeaker = 'Leonardo';
      const dialogContent = 'This is my text';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addDialogVerify(dialogTitle, dialogSpeaker, dialogContent);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Table', async () => {
      const tableCaption = 'My table Caption';
      const tableData = {
        c1: 'My cell 1',
        c2: 'My cell 2',
      };

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addTableVerify(tableCaption, tableData.c1, tableData.c2);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Theorem', async ({ page }) => {
      const title = 'Theorem Title';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addTheoremVerify(title);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Conjugation', async ({ page }) => {
      const dataTable = {
        headColumn1: 'Singular',
        headColumn2: 'Plural',
        headRow1: '1st Person',
        headRow2: '2nd Person',
        headRow3: '3rd Person',
      };

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus
        .project()
        .page.addConjugationVerify(
          dataTable.headColumn1,
          dataTable.headColumn2,
          dataTable.headRow1,
          dataTable.headRow2,
          dataTable.headRow3,
        );
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Description List', async ({ page }) => {
      const title = 'My title';
      const term = 'My term';
      const definition = 'My definition';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addDescriptionListVerify(title, term, definition);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Audio clip', async () => {
      const audioFileName = 'audio-test-01.mp3';
      const audioCaption = 'My Audio Caption';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addAudioClipVerify(audioFileName, audioCaption);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Video', async () => {
      const videoFileName = 'video-test-01.mp4';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addVideoVerify(videoFileName);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Insert YouTube', async () => {
      const youtubeUrl = 'https://www.youtube.com/watch?v=2QAMzupR_C4';
      const youtubeId = '2QAMzupR_C4';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addYoutubeVerify(youtubeUrl, youtubeId);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Web page', async () => {
      const webPageUrl = 'https://es.wikipedia.org/wiki/Wikipedia:Portada';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addWebPageVerify(webPageUrl);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Code block', async () => {
      const codeType = 'python';
      const code = 'print("Hola, mundo!")';
      const caption = 'Test Code block';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addCodeBlockVerify(codeType, code, caption);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Figure', async () => {
      const title = 'Test Figure Title';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addFigureVerify(title);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Page link', async () => {
      const pageName = 'New Page';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addPageLinkVerify(pageName);
      await torus.project().deletePage(nameProject);
    });

    test('TQA-13-Definition', async () => {
      const term = 'Algorithm';
      const description =
        'A set of rules or instructions that specify how to solve a problem or perform a task';

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter(typePage, nameProject);
      await torus.project().page.addDefinitionVerify(term, description);
      await torus.project().deletePage(nameProject);
    });
  });

  test.describe('TQA-14 - Add an ungraded page to the curriculum, add at least one type of each activity and edit them', () => {
    const nameProject = 'TQA-14-Automation';

    test.beforeEach(async () => {
      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter('basic-practice', nameProject);
    });

    test.afterEach(async () => {
      await torus.project().deletePage(nameProject);
    });

    test('TQA-14-CATA', async () => {
      await torus.project().page.activity.addCataVerify(questionText);
    });

    test('TQA-14-MCQ', async () => {
      await torus.project().page.activity.addMcqVerify(questionText);
    });

    test('TQA-14-Order', async () => {
      await torus.project().page.activity.addOrderVerify(questionText);
    });

    test('TQA-14-Input', async () => {
      await torus.project().page.activity.addInputVerify(questionText);
    });
  });

  test.describe('TQA-15 - Add an ungraded page to the curriculum, add at least one type of each activity and edit them', () => {
    const nameProject = 'TQA-15-Automation';
    const projectId = 'tqa15automation';
    const pageOverview = `${testData.baseUrl}/workspaces/course_author/${projectId}/overview`;
    let sidebar: SidebarCO;
    let curriculum: CurriculumPO;
    let scoredPage: BasicScoredPagePO;
    let utils: Utils;

    test.beforeEach(async ({ page }) => {
      sidebar = new SidebarCO(page);
      curriculum = new CurriculumPO(page);
      scoredPage = new BasicScoredPagePO(page);
      utils = new Utils(page);

      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter('basic-scored', nameProject);
      await scoredPage.visibleTitlePage();
      await scoredPage.clickInsertButtonIcon();
    });

    test.afterEach(async () => {
      await utils.sleep(2);
      await torus.goToSite(pageOverview);
      await sidebar.author.clickCurriculum();
      await curriculum.delete.openPageDropdownMenu();
      await curriculum.delete.clickShowDeleteModalButton();
      await curriculum.delete.confirmDeletePage();
    });

    test('TQA-15-Vlab', async ({ page }) => {
      const activityType = 'vlab';
      const vlab = new VlabCO(page);

      await scoredPage.selectActivity(activityType);
      await vlab.expectEditorLoaded();
      await vlab.fillQuestion(questionText);
      await vlab.clickAddInputButton();
      await scoredPage.waitForChangesSaved();
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectVlabActivity(questionText);
      await preview.close();
    });

    test('TQA-15-DD', async ({ page }) => {
      const activityType = 'dd';
      const dd = new DdCO(page);

      await scoredPage.selectActivity(activityType);
      await dd.expectEditorLoaded();
      await dd.fillQuestion(questionText);
      await scoredPage.waitForChangesSaved();
      await utils.sleep(2);
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectDdActivity(questionText);
      await preview.close();
    });

    test('TQA-15-Response Multi', async ({ page }) => {
      const activityType = 'response_multi';
      const response = new ResponseCO(page);

      await scoredPage.selectActivity(activityType);
      await response.expectEditorLoaded();
      await response.fillQuestion(questionText);
      await response.clickAddInputButton();
      await scoredPage.waitForChangesSaved();
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectResponseActivity(questionText);
      await preview.close();
    });

    test('TQA-15-Multi', async ({ page }) => {
      const activityType = 'multi';
      const multi = new MultiCO(page);

      await scoredPage.selectActivity(activityType);
      await multi.expectEditorLoaded();
      await multi.fillQuestion(questionText);
      await multi.clickAddInputButton();
      await scoredPage.waitForChangesSaved();
      await utils.sleep(2);
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectMultiActivity(questionText);
      await preview.close();
    });

    test('TQA-15-Likert', async ({ page }) => {
      const activityType = 'likert';
      const likert = new LikertCO(page);

      await scoredPage.selectActivity(activityType);
      await likert.expectEditorLoaded();
      await likert.fillPrompt(questionText);
      await scoredPage.waitForChangesSaved();
      await utils.sleep(2);
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectLikertActivity(questionText);
      await preview.close();
    });

    test('TQA-15-DnD', async ({ page }) => {
      const activityType = 'dnd';
      const dnd = new DndCO(page);

      await scoredPage.selectActivity(activityType);
      await dnd.expectEditorLoaded();
      await dnd.fillQuestion(questionText);
      await scoredPage.waitForChangesSaved();
      await utils.sleep(2);
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectDndActivity(questionText);
      await preview.close();
    });

    test('TQA-15-Upload', async ({ page }) => {
      const activityType = 'file_aupload';
      const upload = new FileUploadCO(page);

      await scoredPage.selectActivity(activityType);
      await upload.expectEditorLoaded();
      await upload.fillQuestion(questionText);
      await scoredPage.waitForChangesSaved();
      await utils.sleep(2);
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectUploadActivity(questionText);
      await preview.close();
    });

    test('TQA-15-Coding', async ({ page }) => {
      const activityType = 'coding';
      const coding = new CodingCO(page);

      await scoredPage.selectActivity(activityType);
      await coding.expectEditorLoaded();
      await coding.fillQuestion(questionText);
      await scoredPage.waitForChangesSaved();
      await utils.sleep(2);
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectCodingActivity(questionText);
      await preview.close();
    });

    test('TQA-15-Hotspot', async ({ page }) => {
      const activityType = 'hotspot';
      const hotspot = new HotspotCO(page);

      await scoredPage.selectActivity(activityType);
      await hotspot.expectEditorLoaded();
      await hotspot.fillQuestion(questionText);
      await scoredPage.waitForChangesSaved();
      await utils.sleep(2);
      const preview = await scoredPage.clickPreview();
      await preview.verifications.expectHotspotActivity(questionText);
      await preview.close();
    });
  });
});
