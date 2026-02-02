import { Page } from '@playwright/test';
import { FileManager } from '@core/FileManager';
import { Table } from '@core/Table';
import { Utils } from '@core/Utils';
import { QuestionActivities, EditorTitle } from '@pom/activities/QuestionActivities';
import { CodeBlockCO } from '@pom/content/CodeBlock';
import { DescriptionListCO } from '@pom/content/DescriptionListCO';
import { DialogCO } from '@pom/content/DialogCO';
import { InsertYouTubeCO } from '@pom/content/InsertYouTubeCO';
import { PopUpCO } from '@pom/content/PopUpCO';
import { SelectCitationCO } from '@pom/content/SelectCitationCO';
import { SelectForeignLanguageCO } from '@pom/content/SelectForeingLanguageCO';
import { SelectPageCO } from '@pom/content/SelectPageCO';
import { TermCO } from '@pom/content/TermCO';
import { WebPageCO } from '@pom/content/WebPageCO';
import { BasicPracticePagePO } from '@pom/page/BasicPracticePagePO';
import { SelectMultimediaCO } from '@pom/page/SelectMultimediaCO';
import { CurriculumPO, Index } from '@pom/project/CurriculumPO';
import { OverviewProjectPO } from '@pom/project/OverviewProjectPO';
import { TypeActivity } from '@pom/types/type-activity';
import { TypeProgrammingLanguage } from '@pom/types/type-programming-language';
import { MediaKind } from '@pom/types/type-select-multemedia';
import { TypeLanguage } from '@pom/types/types-language';
import { TypeToolbar } from '@pom/types/type-toolbar';
import { InstructorDashboardPO } from '@pom/dashboard/InstructorDashboardPO';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';
import { CourseManagePO } from '@pom/course/CourseManagePO';
import { QuestionVlabCO } from '@pom/activities/QuestionVlabCO';
import { QuestionResponseCO } from '@pom/activities/QuestionResponseCO';
import { QuestionMultiCO } from '@pom/activities/QuestionMultiCO';
import { QuestionLikertCO } from '@pom/activities/QuestionLikertCO';
import { step } from '@core/decoration/step';
import { QuestionImageHotspot } from '@pom/activities/QuestionImageHotspot';

type PageType = 'basic-practice' | 'basic-scored' | 'adaptive-practice' | 'unit' | 'module';

export class CurriculumTask {
  private readonly basicPP: BasicPracticePagePO;
  private readonly selectM: SelectMultimediaCO;
  private readonly overviewP: OverviewProjectPO;
  private readonly curriculum: CurriculumPO;
  private readonly instructorDB: InstructorDashboardPO;
  private readonly newCS: NewCourseSetupPO;
  private readonly detailCourse: CourseManagePO;
  private readonly utils: Utils;

  constructor(private readonly page: Page) {
    this.basicPP = new BasicPracticePagePO(page);
    this.selectM = new SelectMultimediaCO(page);
    this.overviewP = new OverviewProjectPO(page);
    this.curriculum = new CurriculumPO(page);
    this.instructorDB = new InstructorDashboardPO(page);
    this.newCS = new NewCourseSetupPO(page);
    this.detailCourse = new CourseManagePO(page);
    this.utils = new Utils(page);
  }

  @step('Focus first paragraph')
  async focusFirstParagraph() {
    await this.basicPP.clickParagraph(0);
  }

  @step("Add a resource '{fileName}' to the project")
  async uploadMediaFile(kind: MediaKind, fileName: string) {
    if (kind === 'image') {
      await this.clickOnParagraphAndSelectContent(0, 'More', 'Image (Inline)');
    }

    if (kind === 'audio') {
      await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Audio Clip');
      await this.selectM.waitForLabel('Embed audio');
    }

    if (kind === 'video') {
      await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Video');
      await this.selectM.clickChooseVideo();
      await this.selectM.waitForLabel('Select Video');
    }

    const fileChooserPromise = this.page.waitForEvent('filechooser');
    await this.selectM.clickUploadButton();
    const fileChooser = await fileChooserPromise;
    const mediaPath = FileManager.mediaPath(fileName);
    await fileChooser.setFiles(mediaPath);
    await this.selectM.verifyResourceUploadedCorrectly(fileName);
    await this.selectM.closeSelectMedia();
  }

  @step("Select a media file '{fileName}'")
  async selectMediaFile(kind: MediaKind, fileName: string) {
    if (kind === 'image') {
      const selectImage = await this.basicPP.clickChoseImage();
      await selectImage.waitForLabel('Select Image');
      await selectImage.selectMediaByName(fileName);
      await selectImage.confirmSelection();
    }
  }

  @step("Set the activity state to '{stateToClick}'")
  async setActivityState(activity: TypeActivity, stateToClick: 'Enable' | 'Disable') {
    await this.overviewP.advancedActivities.setActivityState(activity, stateToClick);
  }

  @step('Add a page and enter. Type: {type}')
  async addPageAndEnter(
    type: PageType,
    namePage = 'New Page',
    link = 'Edit Page',
    index: Index = 'last',
  ) {
    await this.addPage(type);
    await this.enterPage(type, namePage, link, index);

    if (type === 'basic-practice') {
      await this.basicPP.verifyTitlePage(namePage);
    }
  }

  @step('Create and enter a unit')
  async createAndEnterUnit(name: string) {
    await this.addPage('unit');
    await this.curriculum.clickEditUnitLink(name);
  }

  @step('Create and enter a module')
  async createAndEnterModule(name: string) {
    await this.addPage('module');
    await this.curriculum.clickEditModuleLink(name);
  }

  @step('Add a page to the project. Type: {type}')
  async addPage(type: PageType) {
    switch (type) {
      case 'basic-practice':
        await this.curriculum.clickBasicPracticeButton();
        break;
      case 'basic-scored':
        await this.curriculum.clickBasicScoredButton();
        break;
      case 'adaptive-practice':
        await this.curriculum.clickAdaptivePracticeButton();
        break;
      case 'unit':
        await this.curriculum.clickCreateUnitButton();
        break;
      case 'module':
        await this.curriculum.clickCreateModuleButton();
        break;
    }
  }

  @step('Enter a page from the project. Type: {type}')
  async enterPage(type: PageType, namePage: string, link: string, index: Index) {
    if (type === 'basic-practice' || type === 'basic-scored') {
      await this.curriculum.clickEditPageLink(namePage, link, index);
    }
    if (type === 'unit') {
      await this.curriculum.clickEditUnitLink(link);
    }
    if (type === 'module') {
      await this.curriculum.clickEditModuleLink(link);
    }
  }

  @step('Delete a page from the project')
  async deletePage(name = 'New Page', link = 'Edit Page', index: Index = 'last') {
    await this.curriculum.waitingToBeCentered();
    await this.curriculum.deletePage(name, link, index);
  }

  //region Content
  @step('Add cite')
  async addCiteToolbar(name: string, expectText: string, verify = true) {
    const sc = new SelectCitationCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('More');
    await this.basicPP.selectElementToolbar('Cite');
    await sc.expectDialogTitle('Select citation');
    await sc.selectCitation(name);
    await sc.confirmSelection();
    if (verify) {
      await this.waitChangeVisualizeCite(expectText);
    }
  }

  @step('Add foreign')
  async addForeignToolbar(paragraphText: string, language: TypeLanguage, verify = true) {
    const sf = new SelectForeignLanguageCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.typeInFocusedParagraph(paragraphText);
    await this.basicPP.selectElementToolbar('More');
    await this.basicPP.selectElementToolbar('Foreign');
    await sf.open();
    await sf.expectDialogTitle('Foreign Language Settings');
    await sf.selectLanguage(language);
    await sf.save();
    if (verify) {
      await this.waitChangeVisualize(paragraphText);
    }
  }

  @step('Add image')
  async addImageToolbar(nameImage: string, verify = true) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('More');
    await this.basicPP.selectElementToolbar('Image (Inline)');
    await this.selectM.selectMediaByName(nameImage);
    await this.selectM.confirmSelection();
    if (verify) {
      await this.waitChangeVisualizeMedia(nameImage, 'img');
    }
  }

  @step('Add formula')
  async addFormulaToolbar(formula: string, verify = true) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.typeInFocusedParagraph('formula ');
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('More');
    await this.basicPP.selectElementToolbar('Formula (Inline)');
    if (verify) {
      await this.waitChangeVisualize(formula);
    }
  }

  @step('Add callout')
  async addCalloutToolbar(paragraphText: string, verify = true) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.typeInFocusedParagraph(paragraphText);
    await this.basicPP.selectElementToolbar('More');
    await this.basicPP.selectElementToolbar('Callout');
    if (verify) {
      await this.waitChangeVisualize(paragraphText);
    }
  }

  @step('Add popup')
  async addPopUpToolbar(paragraphText: string, popupText: string, verify = true) {
    const popup = new PopUpCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.typeInFocusedParagraph(paragraphText);
    await this.basicPP.selectElementToolbar('More');
    await this.basicPP.selectElementToolbar('Popup Content');
    await popup.openEditor();
    await popup.fillPopupText(popupText);
    await popup.save();
    if (verify) {
      await this.waitChangeVisualize(paragraphText);
    }
  }

  @step('Add definition')
  async addDefinitionToolbar(termText: string, description: string, verify = true) {
    const term = new TermCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.utils.scrollToBottom();
    await this.basicPP.selectElementToolbar('Definition');
    await term.openEditMode();
    await term.fillTerm(termText);
    await term.fillDescription(description);
    if (verify) {
      await this.waitChangeVisualize(termText);
      await this.waitChangeVisualize(description);
    }
  }

  @step('Add page link')
  async addPageLinkToolbar(pageName: string, verify = true) {
    const sp = new SelectPageCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Page Link');
    await sp.expectDialogTitle();
    await sp.selectPageLink(pageName);
    await sp.confirm();
    if (verify) {
      await this.waitChangeVisualize(pageName);
    }
  }

  @step('Add figure')
  async addFigureToolbar(title: string, verify = true) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Figure');
    await this.basicPP.fillFigureTitle(title);
    if (verify) {
      await this.waitChangeVisualize(title);
    }
  }

  @step('Add web page')
  async addWebPageToolbar(webPageUrl: string, verify = true) {
    const webPage = new WebPageCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Webpage');
    await webPage.expectDialogTitle('Settings');
    await webPage.fillWebpageUrl(webPageUrl);
    await webPage.confirm();
    await this.basicPP.waitForChangesSaved();
    if (verify) {
      await this.waitChangeVisualizeMedia(webPageUrl, 'webpage');
    }
  }

  @step('Add youtube link')
  async addYoutubeToolbar(youtubeUrl: string, youtubeId: string, verify = true) {
    const youtube = new InsertYouTubeCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('YouTube');
    await youtube.expectDialogTitle('Insert YouTube');
    await youtube.fillYouTubeUrl(youtubeUrl);
    await youtube.confirm();
    await this.basicPP.waitForChangesSaved();
    if (verify) {
      await this.waitChangeVisualizeMedia(youtubeId, 'youtube');
    }
  }

  @step('Add video')
  async addVideoToolbar(videoFileName: string, verify = true) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Video');
    await this.selectM.clickChooseVideo();
    await this.selectM.waitForLabel('Select Video');
    await this.selectM.selectMediaByName(videoFileName);
    await this.selectM.confirmSelection();
    if (verify) {
      await this.waitChangeVisualizeMedia(videoFileName, 'video');
    }
  }

  @step('Add audio clip')
  async addAudioClipToolbar(audioFileName: string, audioCaption: string, verify = true) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Audio Clip');
    await this.selectM.waitForLabel('Embed audio');
    await this.selectM.selectMediaByName(audioFileName);
    await this.selectM.confirmOk();
    await this.basicPP.waitForChangesSaved();
    await this.basicPP.fillCaptionAudio(audioCaption);
    if (verify) {
      await this.waitChangeVisualizeMedia(audioFileName, 'audio');
    }
  }

  @step('Add description list')
  async addDescriptionListToolbar(title: string, term: string, definition: string, verify = true) {
    const descriptionList = new DescriptionListCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Description List');
    await this.basicPP.waitForChangesSaved();
    await descriptionList.fillTitle(title);
    await this.basicPP.waitForChangesSaved();
    await descriptionList.fillTerm(term);
    await this.basicPP.waitForChangesSaved();
    await descriptionList.fillDefinition(definition);
    if (verify) {
      await this.waitChangeVisualize(title);
      await this.waitChangeVisualize(term);
      await this.waitChangeVisualize(definition);
    }
  }

  @step('Add equation')
  async addConjugationToolbar(
    headColumn1: string,
    headColumn2: string,
    headRow1: string,
    headRow2: string,
    headRow3: string,
    verify = true,
  ) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Conjugation');
    if (verify) {
      await this.waitChangeVisualize(headColumn1);
      await this.waitChangeVisualize(headColumn2);
      await this.waitChangeVisualize(headRow1);
      await this.waitChangeVisualize(headRow2);
      await this.waitChangeVisualize(headRow3);
    }
  }

  @step('Add dialog')
  async addDialogToolbar(dialogTitle: string, dialogSpeaker: string, dialogContent: string, verify = true) {
    const dialog = new DialogCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Dialog');
    await dialog.fillTitle(dialogTitle);
    await this.basicPP.waitForChangesSaved();
    await dialog.fillNameSpeaker(1, dialogSpeaker);
    await this.basicPP.waitForChangesSaved();
    await dialog.clickAddButton();
    await this.basicPP.waitForChangesSaved();
    await dialog.fillParagraph(dialogContent);
    if (verify) {
      await this.waitChangeVisualize(dialogTitle);
      await this.waitChangeVisualize(dialogSpeaker);
      await this.waitChangeVisualize(dialogContent);
    }
  }

  @step('Add table')
  async addTableToolbar(tableCaption: string, cell1: string, cell2: string, verify = true) {
    const table = new Table(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert Table');
    await this.basicPP.waitForChangesSaved();
    await table.fillCaptionTable(tableCaption);
    await this.basicPP.waitForChangesSaved();
    await table.fillCell(1, 1, cell1);
    await this.basicPP.waitForChangesSaved();
    await table.fillCell(1, 2, cell2);
    if (verify) {
      await this.waitChangeVisualize(cell1, cell2, tableCaption);
    }
  }

  @step('Add theorem')
  async addTheoremToolbar(title: string, verify = true) {
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Theorem');
    if (verify) {
      await this.waitChangeVisualize(title);
    }
  }

  @step('Add code block')
  async addCodeBlockToolbar(codeType: TypeProgrammingLanguage, code: string, caption: string, verify = true) {
    const cb = new CodeBlockCO(this.page);
    await this.basicPP.focusParagraphStart(0);
    await this.basicPP.selectElementToolbar('Insert...');
    await this.basicPP.selectElementToolbar('Code (Block)');
    await cb.selectLanguageCode(codeType);
    await cb.fillCodeEditor(code);
    await cb.fillCodeCaption(caption);
    if (verify) {
      await this.waitChangeVisualize(code, caption);
    }
  }

  @step('Open preview')
  async openPreview() {
    return this.basicPP.clickPreview();
  }

  @step('Click on paragraph and select content')
  async clickOnParagraphAndSelectContent(indexParagraph: number | 'auto' = 'auto', ...elements: TypeToolbar[]) {
    const targetIndex = await this.basicPP.prepareParagraphForInsertion(indexParagraph);
    await this.basicPP.clickParagraph(targetIndex);
    for (const element of elements) {
      await this.basicPP.selectElementToolbar(element);
    }
  }

  @step('Fill on paragraph and select content')
  async fillOnParagraphAndSelectContent(
    text: string,
    indexParagraph: number | 'auto' = 'auto',
    ...elements: TypeToolbar[]
  ) {
    const targetIndex = await this.basicPP.prepareParagraphForInsertion(indexParagraph);
    await this.basicPP.fillParagraph(text, targetIndex);
    for (const element of elements) {
      await this.basicPP.selectElementToolbar(element);
    }
  }

  @step('Wait for changes and view cite')
  async waitChangeVisualizeCite(cite: string) {
    await this.basicPP.waitForChangesSaved();

    const preview = await this.basicPP.clickPreview();
    await preview.verifyCite(cite);
    await preview.close();
  }

  @step('Wait for changes and view them')
  async waitChangeVisualize(...str: string[]) {
    await this.basicPP.waitForChangesSaved();

    const preview = await this.basicPP.clickPreview();
    await preview.verifyContent(...str);
    await preview.close();
  }

  @step('Wait for changes and view multimedia resources')
  async waitChangeVisualizeMedia(
    name: string,
    resourceType: 'audio' | 'img' | 'video' | 'youtube' | 'webpage',
  ) {
    await this.basicPP.waitForChangesSaved();

    const preview = await this.basicPP.clickPreview();
    await preview.verifyMedia(name, resourceType);
    await preview.close();
  }
  //endregion Content

  //region Activity
  @step("Build question activity '{editorTitle}', '{activityType}' and '{questionText}'")
  async buildQuestionActivity(
    editorTitle: EditorTitle,
    activityType: TypeActivity,
    questionText: string,
  ) {
    const activity = new QuestionActivities(this.page, editorTitle);
    this.addQuestionActivity(activityType);
    await activity.expectEditorLoaded();
    await activity.fillQuestion(questionText);
    await this.basicPP.waitForChangesSaved();
  }

  @step('Add question activity')
  async addQuestionActivity(activity: TypeActivity) {
    await this.basicPP.clickInsertButtonIcon();
    await this.basicPP.selectActivity(activity);
    await this.basicPP.waitForChangesSaved();
  }

  @step("Add activities with questions '{editorTitle}', '{activityType}' and '{questionText}'")
  async addActivitiesWithQuestions(
    editorTitle: EditorTitle,
    activityType: TypeActivity,
    questionText: string,
    verify = true,
  ) {
    await this.buildQuestionActivity(editorTitle, activityType, questionText);
    await this.basicPP.waitForChangesSaved();
    await this.page.waitForTimeout(300);

    if (verify) {
      const preview = await this.basicPP.clickPreview();
      await preview.verifyQuestion(questionText);
      await preview.verifyComponent(activityType);
      await preview.close();
    }
  }

  @step('Add activity vlab')
  async addActivityVlab(questionText: string) {
    const vlab = new QuestionVlabCO(this.page);
    await this.addQuestionActivity('vlab');
    await vlab.expectEditorLoaded();
    await vlab.fillQuestion(questionText);
    await vlab.clickAddInputButton();
  }

  @step('Add activity response multi')
  async addActivityResponseMulti(questionText: string) {
    const response = new QuestionResponseCO(this.page);
    await this.addQuestionActivity('response_multi');
    await response.expectEditorLoaded();
    await response.fillQuestion(questionText);
    await response.clickAddInputButton();
  }

  @step('Add activity multi')
  async addActivityMulti(questionText: string) {
    const multi = new QuestionMultiCO(this.page);
    await this.addQuestionActivity('multi');
    await multi.expectEditorLoaded();
    await multi.fillQuestion(questionText);
    await multi.clickAddInputButton();
  }

  @step('Add activity likert')
  async addActivityLikert(questionText: string) {
    const likert = new QuestionLikertCO(this.page);
    await this.addQuestionActivity('likert');
    await likert.expectEditorLoaded();
    await likert.fillPrompt(questionText);
  }

  @step('Add activity Image Hotspot')
  async addActivityHotspot(questionText: string) {
    const hotspot = new QuestionImageHotspot(this.page);
    await this.addQuestionActivity('hotspot');
    await hotspot.expectEditorLoaded();
    await hotspot.fillPrompt(questionText);
  }
  //endregion Activity

  //region Course
  @step("Create a new course section with name '{courseName}' project")
  async createNewCourseSection(courseName: string, startDate: Date, endDate: Date) {
    await this.instructorDB.clickCreateNewSection();
    await this.newCS.step1.searchProject(courseName);
    await this.newCS.step1.clickOnCardProject(courseName);
    await this.newCS.step2.fillCourseName(courseName);
    await this.newCS.step2.fillCourseSectionNumber(courseName);
    await this.newCS.step2.goToNextStep();
    await this.newCS.step3.fillStartDate(startDate);
    await this.newCS.step3.fillEndDate(endDate);
    await this.newCS.step3.submitSection();
  }

  @step("Create a new course section for the '{projectName}' project with id '{projectID}'")
  async createCourseFromProject(
    projectName: string,
    projectID: string,
    startDate: Date,
    endDate: Date,
    baseUrl?: string,
  ) {
    this.createNewCourseSection(projectName, startDate, endDate);

    const origin = baseUrl || new URL(this.page.url()).origin;
    await this.detailCourse.verifyTitlePage(projectName);
    await this.detailCourse.verifyCourseSectionID(projectID);
    await this.detailCourse.verifyTitle(projectName);
    await this.detailCourse.verifyUrl(origin, projectID);
  }

  @step("Create a new course section for the '{productName}' product")
  async createCourseFromProduct(
    productName: string,
    startDate: Date,
    endDate: Date,
    baseUrl?: string,
  ) {
    this.createNewCourseSection(productName, startDate, endDate);

    const origin = baseUrl || new URL(this.page.url()).origin;
    await this.detailCourse.verifyTitlePage(productName);
    await this.detailCourse.verifyTitle(productName);
    const courseSectionID = await this.detailCourse.getCourseSectionID();
    await this.detailCourse.verifyUrl(origin, courseSectionID);
    await this.detailCourse.verifyProductLink(productName);
  }
  //endregion Course
}
