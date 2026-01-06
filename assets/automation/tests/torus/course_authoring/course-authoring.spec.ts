import path from 'node:path';
import { test } from '@fixture/my-fixture';
import { TypeActivity } from '@pom/types/type-activity';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { TYPE_USER } from '@pom/types/type-user';

const runId = `-${Date.now()}`;
const baseUrl = 'http://localhost';
const defaultPassword = 'changeme123456';
const adminPassword = 'changeme123456';
const projectNameFilterSeed = 'automatedtests';

setRuntimeConfig({
  baseUrl,
  scenarioToken: 'my-token',
  loginData: {
    student: {
      type: TYPE_USER.student,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Hi, Jane',
      email: `student${runId}@example.com`,
      name: 'Jane',
      last_name: 'Student',
      pass: defaultPassword,
    },
    instructor: {
      type: TYPE_USER.instructor,
      pageTitle: 'OLI Torus',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Instructor Dashboard',
      email: `instructor${runId}@example.com`,
      pass: defaultPassword,
      header: 'Instructor Dashboard',
    },
    author: {
      type: TYPE_USER.author,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: `author${runId}@example.com`,
      pass: defaultPassword,
      header: 'Course Author',
    },
    administrator: {
      type: TYPE_USER.administrator,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: `admin${runId}@example.com`,
      pass: adminPassword,
      header: 'Course Author',
    },
  },
});
const questionText = 'Question test?';
const mediaDir = path.resolve(__dirname, '../../resources/media_files');
// __dirname = assets/automation/tests/torus/course_authoring
const scenarioPath = path.resolve(__dirname, './playwright_course_authoring.yaml');

test.beforeAll(async ({ seedScenario }) => {
  await seedScenario(
    scenarioPath,
    {
      RUN_ID: runId,
      MEDIA_DIR: mediaDir,
    },
  );
});

test.describe('Course authoring', () => {
  test('Log in as an author and create a new course project with valid details, set the Publishing Visibility as Open', async ({
    homeTask,
    projectTask,
    curriculumTask,
    utils,
  }) => {
    const startDate = new Date();
    const endDate = new Date();
    endDate.setFullYear(endDate.getFullYear() + 1);

    await homeTask.login('author');
    const projectNameFilter = await projectTask.filterAndReturnProject(projectNameFilterSeed);
    const projectNameID = utils.incrementID(projectNameFilter);
    const { projectName, projectID } = await projectTask.createNewProjectAsOpen(projectNameID);
    await homeTask.enterToPublish();
    await projectTask.publishProject();
    await homeTask.logout();
    await homeTask.login('instructor');
    await curriculumTask.createCourseFromProject(
      projectName,
      projectID,
      startDate,
      endDate,
      baseUrl,
    );
  });

  test('Edit project attributes language and license with valid details', async ({
    homeTask,
    projectTask,
  }) => {
    const projectName = `TQA-10-automation${runId}`;
    const languageValue = 'belarusian';
    const licenseValue = 'cc_by';

    await homeTask.login('author');
    await projectTask.searchAndEnterProject(projectName);
    await projectTask.configureProjectAttributes(languageValue, licenseValue);
  });

test.describe('Enable and verify one activity per test', () => {
    const activities: TypeActivity[] = [
      'dnd',
      'dd',
      'coding',
      'file_upload',
      'hotspot',
      'likert',
      'multi',
      'response_multi'
    ];

    const projectName = () => `TQA-11-automation${runId}`;

    test('Enable all advanced activities, use each once, then disable all', async ({
      homeTask,
      curriculumTask,
      projectTask,
    }) => {
      await homeTask.login('author');
      await projectTask.searchAndEnterProject(projectName());

      // Enable all activities
      await homeTask.enterToOverview();
      await projectTask.overviewP.advancedActivities.openAddActivitiesAndTools();
      for (const activity of activities) {
        await curriculumTask.setActivityState(activity, 'Enable');
      }
      await projectTask.overviewP.advancedActivities.applyChanges();

      // Add a basic page and insert one of each activity
      await homeTask.enterToCurriculum();
      await curriculumTask.addPageAndEnter('basic-practice');
      for (const activity of activities) {
        await curriculumTask.addQuestionActivity(activity);
      }

      // Clean up: delete page
      await homeTask.enterToCourseAuthor();
      await projectTask.searchAndEnterProject(projectName());
      await homeTask.enterToCurriculum();
      await curriculumTask.deletePage();

      // Disable all activities
      await homeTask.enterToOverview();
      await projectTask.overviewP.advancedActivities.openAddActivitiesAndTools();
      for (const activity of activities) {
        await curriculumTask.setActivityState(activity, 'Disable');
      }
      await projectTask.overviewP.advancedActivities.applyChanges();
    });
  });

  test('Modify text, add an image, and change text formatting in an BASIC page', async ({
    homeTask,
    projectTask,
    curriculumTask,
  }) => {
    const projectName = `TQA-12-automation${runId}`;
    const paragraphText = 'Text generated by automation';
    const newParagraphText = 'New text generated by automation';
    const imageFileName = 'img-mock-05-16-2025.jpg';

    await homeTask.login('author');
    await projectTask.searchAndEnterProject(projectName);
    await homeTask.enterToCurriculum();
    await curriculumTask.addPageAndEnter('basic-practice');
    await curriculumTask.fillOnParagraphAndSelectContent(paragraphText);
    await curriculumTask.addQuestionActivity('paragraph');
    await curriculumTask.fillOnParagraphAndSelectContent(newParagraphText, 0, 'Format', 'List');
    await curriculumTask.waitChangeVisualize(newParagraphText, paragraphText);
    await curriculumTask.addQuestionActivity('paragraph');
    await curriculumTask.clickOnParagraphAndSelectContent(0, 'Insert Image');
    await curriculumTask.selectMediaFile('image', imageFileName);
    await curriculumTask.waitChangeVisualizeMedia(imageFileName, 'img');
    await homeTask.enterToCurriculum();
    await curriculumTask.deletePage();
  });

  test.describe('Add one of each type of content to dedicated pages', () => {
    const projectName = `TQA-13-automation${runId}`;

    const pages = [
      { title: 'Cite', action: async (ct: any) => ct.addCiteToolbar('Newton, I.', 'Newton', false), verify: async (p: any) => p.verifyCite('Newton') },
      { title: 'Foreign', action: async (ct: any) => ct.addForeignToolbar('Text generated by automation', 'arabic', false), verify: async (p: any) => p.verifyTextAnywhere('Text generated by automation') },
      { title: 'Image', action: async (ct: any) => ct.addImageToolbar('img-mock-05-16-2025.jpg', false), verify: async (p: any) => p.verifyMedia('img-mock-05-16-2025.jpg', 'img') },
      { title: 'Formula', action: async (ct: any) => ct.addFormulaToolbar('1+2=3', false), verify: async (p: any) => p.verifyTextAnywhere('1+2=3') },
      {
        title: 'Callout',
        action: async (ct: any) =>
          ct.addCalloutToolbar(
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
            false,
          ),
        verify: async (p: any) => p.verifyTextAnywhere('Lorem ipsum dolor sit amet'),
      },
      {
        title: 'Popup',
        action: async (ct: any) => ct.addPopUpToolbar('Text generated by automation', 'Popup text', false),
        verify: async (p: any) => {
          await p.hoverText('Text generated by automation');
          await p.verifyTextAnywhere('Popup text');
        },
      },
      {
        title: 'Dialog',
        action: async (ct: any) => ct.addDialogToolbar("This is a dialog's title", 'Leonardo', 'This is my text', false),
        verify: async (p: any) => p.verifyTextAnywhere("This is a dialog's title"),
      },
      { title: 'Table', action: async (ct: any) => ct.addTableToolbar('My table Caption', 'My cell 1', 'My cell 2', false), verify: async (p: any) => p.verifyTextAnywhere('My cell 1') },
      { title: 'Theorem', action: async (ct: any) => ct.addTheoremToolbar('Theorem Title', false), verify: async (p: any) => p.verifyTextAnywhere('Theorem Title') },
      {
        title: 'Conjugation',
        action: async (ct: any) => ct.addConjugationToolbar('Singular', 'Plural', '1st Person', '2nd Person', '3rd Person', false),
        verify: async (p: any) => p.verifyTextAnywhere('Singular'),
      },
      { title: 'Description List', action: async (ct: any) => ct.addDescriptionListToolbar('My title', 'My term', 'My definition', false), verify: async (p: any) => p.verifyTextAnywhere('My definition') },
      { title: 'Audio', action: async (ct: any) => ct.addAudioClipToolbar('audio-test-01.mp3', 'My Audio Caption', false), verify: async (p: any) => p.verifyMedia('audio-test-01.mp3', 'audio') },
      { title: 'Video', action: async (ct: any) => ct.addVideoToolbar('video-test-01.mp4', false), verify: async (p: any) => p.verifyMedia('video-test-01.mp4', 'video') },
      { title: 'YouTube', action: async (ct: any) => ct.addYoutubeToolbar('https://www.youtube.com/watch?v=2QAMzupR_C4', '2QAMzupR_C4', false), verify: async (p: any) => p.verifyMedia('2QAMzupR_C4', 'youtube') },
      { title: 'Webpage', action: async (ct: any) => ct.addWebPageToolbar('https://es.wikipedia.org/wiki/Wikipedia:Portada', false), verify: async (p: any) => p.verifyMedia('es.wikipedia.org/wiki/Wikipedia:Portada', 'webpage') },
      { title: 'Code Block', action: async (ct: any) => ct.addCodeBlockToolbar('python', 'print("Hola, mundo!")', 'Test Code block', false), verify: async (p: any) => p.verifyTextAnywhere('Hola, mundo') },
      { title: 'Figure', action: async (ct: any) => ct.addFigureToolbar('Test Figure Title', false), verify: async (p: any) => p.verifyTextAnywhere('Test Figure Title') },
      { title: 'Page Link', action: async (ct: any) => ct.addPageLinkToolbar('Page 1', false), verify: async (p: any) => p.verifyTextAnywhere('Page 1') },
      {
        title: 'Definition',
        action: async (ct: any) =>
          ct.addDefinitionToolbar(
            'Algorithm',
            'A set of rules or instructions that specify how to solve a problem or perform a task',
            false,
          ),
        verify: async (p: any) => p.verifyTextAnywhere('Algorithm'),
      },
    ];

    test.beforeEach(async ({ homeTask, projectTask }) => {
      await homeTask.login('author');
      await projectTask.searchAndEnterProject(projectName);
      await homeTask.enterToCurriculum();
    });

    for (const page of pages) {
      test(`Content: ${page.title}`, async ({ homeTask, projectTask, curriculumTask }) => {
        await curriculumTask.enterPage('basic-practice', page.title, 'Edit Page', 'last');
        await curriculumTask.focusFirstParagraph();
        await page.action(curriculumTask);
        const preview = await curriculumTask.openPreview();
        await page.verify(preview);
        await preview.close();
      });
    }
  });

  test('Publish project as admin and create section as instructor', async ({
    homeTask,
    projectTask,
    curriculumTask,
    utils,
  }) => {
    const startDate = new Date();
    const endDate = new Date();
    endDate.setFullYear(endDate.getFullYear() + 1);

    await homeTask.login('author');
    const projectNameFilter = await projectTask.filterAndReturnProject(projectNameFilterSeed);
    const projectNameID = `${utils.incrementID(projectNameFilter)}${runId}`;
    const { projectName, projectID } = await projectTask.createNewProjectAsOpen(projectNameID);
    await homeTask.enterToPublish();
    await projectTask.publishProject();
    await homeTask.logout();
    await homeTask.login('instructor');
    await curriculumTask.createCourseFromProject(
      projectName,
      projectID,
      startDate,
      endDate,
      baseUrl,
    );
  });

  test('Publish updates to a project with the auto-publishing checkbox checked. Then log in as a student pick the section created from the project, go to Learn, and verify that the changes appear', async ({
    homeTask,
    curriculumTask,
    projectTask,
    studentTask,
  }) => {
    const projectName = `TQA-19-automation${runId}`;
    const pageName = ['New Page', 'New Assessment', 'New Adaptive Page'];
    const description = 'New version of the project';

    await homeTask.login('author');
    await projectTask.searchAndEnterProject(projectName);
    await homeTask.enterToCurriculum();
    await curriculumTask.addPage('basic-practice');
    await curriculumTask.addPage('basic-scored');
    await curriculumTask.addPage('adaptive-practice');
    await homeTask.enterToPublish();
    await projectTask.publishProject(description);
    await homeTask.logout();
    await homeTask.login('student');
    await studentTask.searchProject(projectName);
    await homeTask.enterToLearn();
    await studentTask.validateResource(pageName);
  });

  test('Publish project and create product as instructor', async ({
    page,
    homeTask,
    projectTask,
    curriculumTask,
    utils,
  }) => {
    const startDate = new Date();
    const endDate = new Date();
    endDate.setFullYear(startDate.getFullYear() + 1);

    await homeTask.login('author');
    const projectNameFilter = await projectTask.filterAndReturnProject(projectNameFilterSeed);
    const projectNameID = utils.incrementID(projectNameFilter);
    const { projectName } = await projectTask.createNewProjectAsOpen(projectNameID);
    await homeTask.enterToPublish();
    await projectTask.publishProject();
    await homeTask.enterToProducts();
    const { productName } = await projectTask.createAndOpenProduct(projectName);
    await homeTask.logout();
    await homeTask.login('instructor');
    await curriculumTask.createCourseFromProduct(productName, startDate, endDate, baseUrl);
  });
});
