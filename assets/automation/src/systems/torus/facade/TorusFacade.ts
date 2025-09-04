import { Utils } from '@core/Utils';
import { Page } from '@playwright/test'; 
import { CataCO } from '@pom/component/activities/CataCO';
import { InputCO } from '@pom/component/activities/InputCO';
import { McqCO } from '@pom/component/activities/McqCO';
import { OrderCO } from '@pom/component/activities/OrderCO';
import { MenuDropdownCO } from '@pom/component/MenuDropdownCO';
import { SelectMultimediaCO } from '@pom/component/SelectMultimediaCO';
import { ToolbarCO } from '@pom/component/toolbar/ToolbarCO';
import { LoginPO } from '@pom/login/LoginPO';
import { BasicPracticePagePO } from '@pom/page/BasicPracticePagePO';
import { BasicScoredPagePO } from '@pom/page/BasicScoredPagePO';
import { CurriculumPO } from '@pom/project/CurriculumPO';
import { ActivityType } from '@pom/types/activity-types';
import { LanguageCodeType } from '@pom/types/language-code-types';
import { LanguageType } from '@pom/types/language-types';
import { USER_TYPES, UserType } from '@pom/types/user-type';
import { AdminAllUsersPO } from '@pom/workspace/administrator/AdminAllUsersPO';
import { AdminUserDetailsPO } from '@pom/workspace/administrator/AdminUserDetailsPO';
import { WorkspaceAuthorPO } from '@pom/workspace/author/WorkspaceAuthorPO';
import { WorkspaceInstructorPO } from '@pom/workspace/instructor/WorkspaceInstructorPO';
import { WorkspaceStudentPO } from '@pom/workspace/student/WorkspaceStudentPO';
import { TestData } from 'tests/torus/test-data';

export class TorusFacade {
  //data and config
  private readonly testData: TestData;
  private readonly environment: string;
  private readonly utils: Utils;

  //PO
  private readonly loginpo: LoginPO;
  private readonly wss: WorkspaceStudentPO;
  private readonly wsi: WorkspaceInstructorPO;
  private readonly wsa: WorkspaceAuthorPO;
  private readonly adminAllUsers: AdminAllUsersPO;
  private readonly adminUserDetails: AdminUserDetailsPO;
  private readonly curriculum: CurriculumPO;
  private readonly bpp: BasicPracticePagePO;
  private readonly bsp: BasicScoredPagePO;

  //CO
  private readonly menu: MenuDropdownCO;
  private readonly toolbar: ToolbarCO;
  private readonly selectMultimedia: SelectMultimediaCO;
  private readonly cata: CataCO;
  private readonly input: InputCO;
  private readonly mcq: McqCO;
  private readonly order: OrderCO;

  constructor(private page: Page, environment?: string) {
    //data and config
    this.testData = new TestData();
    this.environment = environment ?? '/';
    this.utils = new Utils(page);

    //PO
    this.loginpo = new LoginPO(page);
    this.wss = new WorkspaceStudentPO(page);
    this.wsi = new WorkspaceInstructorPO(page);
    this.wsa = new WorkspaceAuthorPO(page);
    this.adminAllUsers = new AdminAllUsersPO(page);
    this.adminUserDetails = new AdminUserDetailsPO(page);
    this.curriculum = new CurriculumPO(page);
    this.bpp = new BasicPracticePagePO(page);
    this.bsp = new BasicScoredPagePO(page);

    //CO
    this.menu = new MenuDropdownCO(page);
    this.toolbar = new ToolbarCO(page);
    this.selectMultimedia = new SelectMultimediaCO(page);
    this.cata = new CataCO(page);
    this.input = new InputCO(page);
    this.mcq = new McqCO(page);
    this.order = new OrderCO(page);
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

  async log_in(
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
    if (role === USER_TYPES.INSTRUCTOR) await this.wsi.verifyHeader(headerVerify);
    if (role === USER_TYPES.AUTHOR) await this.wsa.verifyHeader(headerVerify);
    if (role === USER_TYPES.ADMIN) await this.wsa.verifyHeader(headerVerify);
  }

  async login(role: UserType, coockies: boolean = true) {
    if (role === USER_TYPES.STUDENT) await this.loginStuden(coockies);
    if (role === USER_TYPES.INSTRUCTOR) await this.loginInstructor(coockies);
    if (role === USER_TYPES.AUTHOR) await this.loginAuthor(coockies);
    if (role === USER_TYPES.ADMIN) await this.loginAdmin(coockies);
  }

  async loginStuden(coockies: boolean) {
    const student = this.testData.loginData.student;

    if (coockies) {
      await this.utils.sleep(2);
      await this.loginpo.acceptCookies();
    }

    await this.loginpo.selectRoleAccount(student.type);
    await this.page.waitForLoadState();
    await this.loginpo.verifyTitle(student.pageTitle);
    await this.loginpo.verifyRole(student.role);
    await this.loginpo.verifyWelcomeText(student.welcomeText);
    await this.loginpo.fillEmail(student.email);
    await this.loginpo.fillPassword(student.pass);
    await this.loginpo.clickSignInButton();
    await this.wss.verifyName(student.name);
  }

  async loginInstructor(coockies: boolean) {
    const instructor = this.testData.loginData.instructor;

    if (coockies) {
      await this.utils.sleep(2);
      await this.loginpo.acceptCookies();
    }

    await this.loginpo.selectRoleAccount(instructor.type);
    await this.page.waitForLoadState();
    await this.loginpo.verifyTitle(instructor.pageTitle);
    await this.loginpo.verifyRole(instructor.role);
    await this.loginpo.verifyWelcomeText(instructor.welcomeText);
    await this.loginpo.fillEmail(instructor.email);
    await this.loginpo.fillPassword(instructor.pass);
    await this.loginpo.clickSignInButton();
    await this.wsi.verifyHeader(instructor.header);
  }

  async loginAuthor(coockies: boolean) {
    const author = this.testData.loginData.author;

    if (coockies) {
      await this.utils.sleep(2);
      await this.loginpo.acceptCookies();
    }

    await this.loginpo.selectRoleAccount(author.type);
    await this.page.waitForLoadState();
    await this.loginpo.verifyTitle(author.pageTitle);
    await this.loginpo.verifyRole(author.role);
    await this.loginpo.verifyWelcomeText(author.welcomeText);
    await this.loginpo.fillEmail(author.email);
    await this.loginpo.fillPassword(author.pass);
    await this.loginpo.clickSignInButton();
    await this.wsa.verifyHeader(author.header);
  }

  async loginAdmin(coockies: boolean) {
    const admin = this.testData.loginData.admin;
    const author = this.testData.loginData.author;

    if (coockies) {
      await this.utils.sleep(2);
      await this.loginpo.acceptCookies();
    }

    await this.loginpo.selectRoleAccount(author.type);
    await this.page.waitForLoadState();
    await this.loginpo.verifyTitle(author.pageTitle);
    await this.loginpo.verifyRole(author.role);
    await this.loginpo.verifyWelcomeText(author.welcomeText);
    await this.loginpo.fillEmail(admin.email);
    await this.loginpo.fillPassword(admin.pass);
    await this.loginpo.clickSignInButton();
    await this.wsa.verifyHeader(author.header);
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
    await this.wsi.dashboard.sectionCreation.clickCreateNewSection();

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
    await this.wsi.dashboard.sectionCreation.clickCreateNewSection();

    await this.wsi.newCourseSetup.step1.verifyTextStepperContent(textToVerify);
  }

  sidebar() {
    return {
      clickCourseAuthor: async () => await this.wsa.sidebar.workspace.clickAuthor(),
      clickInstructor: async () => await this.wsa.sidebar.workspace.clickInstructor(),
      clickStudent: async () => await this.wsa.sidebar.workspace.clickStudent(),
    };
  }

  project() {
    return {
       overview: {
        enableActivity: async (projectId: string, activity: ActivityType) => {
          await this.wsa.overviewProject.advancedActivities.enableActivity(projectId, activity);
        },
        disableActivity: async (projectId: string, activity: ActivityType) => {
          await this.wsa.overviewProject.advancedActivities.disableActivity(projectId, activity);
        },
      },

      addPageAndEnter: async (type: 'basic-practice' | 'basic-scored', projectName: string) => {
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

        await this.curriculum.create.clickEditPageLink();

        if (type === 'basic-practice') await this.bpp.visibleTitlePage();
        if (type === 'basic-scored') await this.bsp.visibleTitlePage();
      },

      deletePage: async (projectName: string) => {
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
      },

      page: {
        addCiteVerify: async (name: string, id: string, expectText: string) => {
          const sc = this.toolbar.selectCitation();

          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('More');
          await this.bpp.selectElementToolbar('Cite');
          await sc.expectDialogTitle('Select citation');
          await sc.selectCitation(name);
          await sc.confirmSelection();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectCitation(id, expectText);
          await preview.close();
        },
        addForeignVerify: async (paragraphText: string, language: LanguageType) => {
          const sf = this.toolbar.selectForeingLanguage();

          await this.bpp.fillParagraph(paragraphText);
          await this.bpp.selectElementToolbar('More');
          await this.bpp.selectElementToolbar('Foreign');
          await sf.open();
          await sf.expectDialogTitle('Foreign Language Settings');
          await sf.selectLanguage(language);
          await sf.save();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectLanguage(language);
          await this.wsa.sidebar.workspace.clickAuthor();
          preview.close();
        },
        addImageVerify: async (nameImage: string) => {
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('More');
          await this.bpp.selectElementToolbar('Image (Inline)');
          await this.selectMultimedia.selectMediaByName(nameImage);
          await this.selectMultimedia.confirmSelection();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectImage(nameImage);
          preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addFormulaVerify: async (formula: string) => {
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('More');
          await this.bpp.selectElementToolbar('Formula (Inline)');
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectFormula(formula);
          preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addCalloutVerify: async (paragraphText: string) => {
          await this.bpp.fillParagraph(paragraphText);
          await this.bpp.selectElementToolbar('More');
          await this.bpp.selectElementToolbar('Callout');
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectCallout();
          preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addPopUpVerify: async (paragraphText: string, popupText: string) => {
          const popup = this.toolbar.popup();

          await this.bpp.fillParagraph(paragraphText);
          await this.bpp.selectElementToolbar('More');
          await this.bpp.selectElementToolbar('Popup Content');
          await popup.openEditor();
          await popup.fillPopupText(popupText);
          await popup.save();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectPopup(paragraphText, popupText);
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addDefinitionVerify: async (termText: string, description: string) => {
          const term = this.toolbar.term();

          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.utils.scrollToBottom();
          await this.bpp.selectElementToolbar('Definition');
          await term.openEditMode();
          await term.fillTerm(termText);
          await term.fillDescription(description);
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectDefinitionTerm(termText, description);
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addPageLinkVerify: async (pageName: string) => {
          const sp = this.toolbar.selePage();

          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Page Link');
          await sp.expectDialogTitle();
          await sp.selectPageLink(pageName);
          await sp.confirm();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectPageLink('New Page');
          await preview.close();
          await this.bpp.deleteAllActivities();
          await this.bpp.waitForChangesSaved();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addFigureVerify: async (title: string) => {
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Figure');
          await this.bpp.fillFigureTitle(title);
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectFigureExists();
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addWebPageVerify: async (webPageUrl: string) => {
          const webPage = this.toolbar.webPage();
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Webpage');
          await webPage.expectDialogTitle('Settings');
          await webPage.fillWebpageUrl(webPageUrl);
          await webPage.confirm();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectWebPage(webPageUrl);
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addYoutubeVerify: async (youtubeUrl: string, youtubeId: string) => {
          const youtube = this.toolbar.insertYoutube();
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('YouTube');
          await youtube.expectDialogTitle('Insert YouTube');
          await youtube.fillYouTubeUrl(youtubeUrl);
          await youtube.confirm();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectYouTubeVideo(youtubeId);
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addVideoVerify: async (videoFileName: string) => {
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Video');
          await this.selectMultimedia.clickChooseVideo();
          await this.selectMultimedia.waitForLabel('Select Video');
          await this.selectMultimedia.selectMediaByName(videoFileName);
          await this.selectMultimedia.confirmSelection();
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectVideo(videoFileName);
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addAudioClipVerify: async (audioFileName: string, audioCaption: string) => {
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Audio Clip');
          await this.selectMultimedia.waitForLabel('Embed audio');
          await this.selectMultimedia.selectMediaByName(audioFileName);
          await this.selectMultimedia.confirmOk();
          await this.bpp.waitForChangesSaved();
          await this.bpp.fillCaptionAudio(audioCaption);
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectAudio(audioFileName);
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addDescriptionListVerify: async (title: string, term: string, definition: string) => {
          const descriptionList = this.toolbar.descriptionList();
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Description List');
          await this.bpp.waitForChangesSaved();
          await descriptionList.fillTitle(title);
          await this.bpp.waitForChangesSaved();
          await descriptionList.fillTerm(term);
          await this.bpp.waitForChangesSaved();
          await descriptionList.fillDefinition(definition);
          await this.bpp.waitForChangesSaved();
          const previewPage = await this.bpp.clickPreview();
          await previewPage.verifications.expectDescriptionList(title, term, definition);
          await previewPage.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addConjugationVerify: async (
          headColumn1: string,
          headColumn2: string,
          headRow1: string,
          headRow2: string,
          headRow3: string,
        ) => {
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Conjugation');
          await this.bpp.waitForChangesSaved();
          const previewPage = await this.bpp.clickPreview();
          await previewPage.verifications.expectConjugationTable(1, 2, headColumn1);
          await previewPage.verifications.expectConjugationTable(1, 3, headColumn2);
          await previewPage.verifications.expectConjugationTable(2, 1, headRow1);
          await previewPage.verifications.expectConjugationTable(3, 1, headRow2);
          await previewPage.verifications.expectConjugationTable(4, 1, headRow3);
          await previewPage.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addDialogVerify: async (
          dialogTitle: string,
          dialogSpeaker: string,
          dialogContent: string,
        ) => {
          const dialog = this.toolbar.dialog();
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Dialog');
          await dialog.fillTitle(dialogTitle);
          await this.bpp.waitForChangesSaved();
          await dialog.fillNameSpeaker(1, dialogSpeaker);
          await this.bpp.waitForChangesSaved();
          await dialog.clickAddButton();
          await this.bpp.waitForChangesSaved();
          await dialog.fillParagraph(dialogContent);
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectDialog(dialogTitle, dialogSpeaker, dialogContent);
          await this.wsa.sidebar.workspace.clickAuthor();
          await preview.close();
        },
        addTableVerify: async (tableCaption: string, cell1: string, cell2: string) => {
          const table = this.toolbar.table();
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert Table');
          await this.bpp.waitForChangesSaved();
          await table.fillCaptionTable(tableCaption);
          await this.bpp.waitForChangesSaved();
          await table.fillCell(1, 1, cell1);
          await this.bpp.waitForChangesSaved();
          await table.fillCell(1, 2, cell2);
          await this.bpp.waitForChangesSaved();
          const previewPage = await this.bpp.clickPreview();
          await previewPage.verifications.expectTableContent(1, 1, cell1);
          await previewPage.verifications.expectTableContent(1, 2, cell2);
          await previewPage.verifications.expectTableCaption(tableCaption);
          await previewPage.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addTheoremVerify: async (title: string) => {
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Theorem');
          await this.bpp.waitForChangesSaved();
          const previewPage = await this.bpp.clickPreview();
          await previewPage.verifications.expectTheorem(title);
          await previewPage.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        addCodeBlockVerify: async (codeType: LanguageCodeType, code: string, caption: string) => {
          const cb = this.toolbar.codeblock();
          await this.bpp.clickParagraph();
          await this.bpp.selectElementToolbar('Insert...');
          await this.bpp.selectElementToolbar('Code (Block)');

          await cb.selectLanguageCode(codeType);
          await cb.fillCodeEditor(code);
          await cb.fillCodeCaption(caption);
          await this.bpp.waitForChangesSaved();
          const preview = await this.bpp.clickPreview();
          await preview.verifications.expectCodeBlock(codeType, code, caption);
          await preview.close();
          await this.wsa.sidebar.workspace.clickAuthor();
        },
        activity: {
          add: async (activity: ActivityType) => {
            await this.bpp.visibleTitlePage();
            await this.bpp.clickInsertButtonIcon();
            await this.bpp.selectActivity(activity);
            await this.bpp.waitForChangesSaved();
            await this.bpp.expectActivityVisible(activity);
          },
          addCataVerify: async (questionText: string) => {
            const activityType = 'cata';
            await this.bpp.clickInsertButtonIcon();
            await this.bpp.selectActivity(activityType);
            await this.cata.expectTitle();
            await this.cata.fillQuestion(questionText);
            await this.bpp.waitForChangesSaved();
            const preview = await this.bpp.clickPreview();
            await preview.verifications.expectActivityWithQuestion(questionText, activityType);
            await preview.close();
            await this.wsa.sidebar.workspace.clickAuthor();
          },
          addMcqVerify: async (questionText: string) => {
            const activityType = 'mcq';
            await this.bpp.clickInsertButtonIcon();
            await this.bpp.selectActivity(activityType);
            await this.mcq.expectEditorLoaded();
            await this.mcq.fillQuestion(questionText);
            await this.bpp.waitForChangesSaved();
            const preview = await this.bpp.clickPreview();
            await preview.verifications.expectActivityWithQuestion(questionText, activityType);
            await preview.close();
            await this.wsa.sidebar.workspace.clickAuthor();
          },
          addOrderVerify: async (questionText: string) => {
            const activityType = 'order';
            await this.bpp.clickInsertButtonIcon();
            await this.bpp.selectActivity(activityType);
            await this.order.expectEditorLoaded();
            await this.order.fillQuestion(questionText);
            await this.bpp.waitForChangesSaved();
            const preview = await this.bpp.clickPreview();
            await preview.verifications.expectActivityWithQuestion(questionText, activityType);
            await preview.close();
            await this.wsa.sidebar.workspace.clickAuthor();
          },
          addInputVerify: async (questionText: string) => {
            const activityType = 'input';
            await this.bpp.clickInsertButtonIcon();
            await this.bpp.selectActivity(activityType);
            await this.input.expectEditorLoaded();
            await this.input.fillQuestion(questionText);
            await this.bpp.waitForChangesSaved();
            await this.utils.sleep(2);
            const preview = await this.bpp.clickPreview();
            await preview.verifications.expectActivityWithQuestion(questionText, activityType);
            await preview.close();
            await this.wsa.sidebar.workspace.clickAuthor();
          },
        },
      },
    };
  }
}
