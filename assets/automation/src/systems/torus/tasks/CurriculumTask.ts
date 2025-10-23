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
import { BasicScoredPagePO } from '@pom/page/BasicScoredPagePO';
import { SelectMultimediaCO } from '@pom/page/SelectMultimediaCO';
import { CurriculumPO } from '@pom/project/CurriculumPO';
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

type PageType = 'basic-practice' | 'basic-scored' | 'unit' | 'module';

export class CurriculumTask {
  private readonly basicPP: BasicPracticePagePO;
  private readonly basicSP: BasicScoredPagePO;
  private readonly selectM: SelectMultimediaCO;
  private readonly overviewP: OverviewProjectPO;
  private readonly curriculum: CurriculumPO;
  private readonly instructorDB: InstructorDashboardPO;
  private readonly newCS: NewCourseSetupPO;
  private readonly detailCourse: CourseManagePO;
  private readonly utils: Utils;

  constructor(private readonly page: Page) {
    this.basicPP = new BasicPracticePagePO(page);
    this.basicSP = new BasicScoredPagePO(page);
    this.selectM = new SelectMultimediaCO(page);
    this.overviewP = new OverviewProjectPO(page);
    this.curriculum = new CurriculumPO(page);
    this.instructorDB = new InstructorDashboardPO(page);
    this.newCS = new NewCourseSetupPO(page);
    this.detailCourse = new CourseManagePO(page);
    this.utils = new Utils(page);
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

  async selectMediaFile(kind: MediaKind, fileName: string) {
    if (kind === 'image') {
      const selectImage = await this.basicPP.clickChoseImage();
      await selectImage.waitForLabel('Select Image');
      await selectImage.selectMediaByName(fileName);
      await selectImage.confirmSelection();
    }
  }

  async setActivityState(activity: TypeActivity, stateToClick: 'Enable' | 'Disable') {
    await this.overviewP.advancedActivities.setActivityState(activity, stateToClick);
  }

  async addPageAndEnter(type: PageType, namePage = 'New Page') {
    await this.addPage(type);
    await this.enterPage(type, namePage);
    await this.basicPP.verifyTitlePage(namePage);
  }

  async addPage(type: PageType) {
    if (type === 'basic-practice') {
      await this.curriculum.clickBasicPracticeButton();
    }
    if (type === 'basic-scored') {
      await this.curriculum.clickBasicScoredButton();
    }
    if (type === 'unit') {
      await this.curriculum.clickCreateUnitButton();
    }
    if (type === 'module') {
      await this.curriculum.clickCreateModuleButton();
    }
  }

  async enterPage(type: PageType, namePage = 'New Page') {
    if (type === 'basic-practice' || type === 'basic-scored') {
      await this.curriculum.clickEditPageLink(namePage);
    }
    if (type === 'unit') {
      await this.curriculum.clickEditUnitLink();
    }
    if (type === 'module') {
      await this.curriculum.clickEditModuleLink();
    }
  }

  @step('Delete a page from the project')
  async deletePage(name = 'New Page') {
    await this.curriculum.deletePage(name);
  }

  //region Content
  async addCiteToolbar(name: string, expectText: string) {
    const sc = new SelectCitationCO(this.page);
    this.clickOnParagraphAndSelectContent(0, 'More', 'Cite');
    await sc.expectDialogTitle('Select citation');
    await sc.selectCitation(name);
    await sc.confirmSelection();
    await this.waitChangeVisualize(expectText);
  }

  async addForeignToolbar(paragraphText: string, language: TypeLanguage) {
    const sf = new SelectForeignLanguageCO(this.page);
    await this.fillOnParagraphAndSelectContent(paragraphText, 0, 'More', 'Foreign');
    await sf.open();
    await sf.expectDialogTitle('Foreign Language Settings');
    await sf.selectLanguage(language);
    await sf.save();
    await this.waitChangeVisualize(paragraphText);
  }

  async addImageToolbar(nameImage: string) {
    await this.clickOnParagraphAndSelectContent(0, 'More', 'Image (Inline)');
    await this.selectM.selectMediaByName(nameImage);
    await this.selectM.confirmSelection();
    await this.waitChangeVisualize(nameImage, 'img');
  }

  async addFormulaToolbar(formula: string) {
    await this.clickOnParagraphAndSelectContent(0, 'More', 'Formula (Inline)');
    await this.waitChangeVisualize(formula);
  }

  async addCalloutToolbar(paragraphText: string) {
    await this.fillOnParagraphAndSelectContent(paragraphText, 0, 'More', 'Callout');
    await this.waitChangeVisualize(paragraphText);
  }

  async addPopUpToolbar(paragraphText: string, popupText: string) {
    const popup = new PopUpCO(this.page);
    await this.fillOnParagraphAndSelectContent(paragraphText, 0, 'More', 'Popup Content');
    await popup.openEditor();
    await popup.fillPopupText(popupText);
    await popup.save();
    await this.waitChangeVisualize(paragraphText);
  }

  async addDefinitionToolbar(termText: string, description: string) {
    const term = new TermCO(this.page);
    await this.basicPP.clickParagraph();
    await this.basicPP.selectElementToolbar('Insert...');
    await this.utils.scrollToBottom();
    await this.basicPP.selectElementToolbar('Definition');
    await term.openEditMode();
    await term.fillTerm(termText);
    await term.fillDescription(description);
    await this.waitChangeVisualize(termText, description);
  }

  async addPageLinkToolbar(pageName: string) {
    const sp = new SelectPageCO(this.page);
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Page Link');
    await sp.expectDialogTitle();
    await sp.selectPageLink(pageName);
    await sp.confirm();
    await this.waitChangeVisualize('New Page');
    await this.basicPP.deleteAllActivities();
    await this.basicPP.waitForChangesSaved();
  }

  async addFigureToolbar(title: string) {
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Figure');
    await this.basicPP.fillFigureTitle(title);
    await this.waitChangeVisualize(title);
  }

  async addWebPageToolbar(webPageUrl: string) {
    const webPage = new WebPageCO(this.page);
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Webpage');
    await webPage.expectDialogTitle('Settings');
    await webPage.fillWebpageUrl(webPageUrl);
    await webPage.confirm();
    await this.basicPP.waitForChangesSaved();
    await this.waitChangeVisualizeMedia(webPageUrl, 'webpage');
  }

  async addYoutubeToolbar(youtubeUrl: string, youtubeId: string) {
    const youtube = new InsertYouTubeCO(this.page);
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'YouTube');
    await youtube.expectDialogTitle('Insert YouTube');
    await youtube.fillYouTubeUrl(youtubeUrl);
    await youtube.confirm();
    await this.basicPP.waitForChangesSaved();
    await this.waitChangeVisualizeMedia(youtubeId, 'youtube');
  }

  async addVideoToolbar(videoFileName: string) {
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Video');
    await this.selectM.clickChooseVideo();
    await this.selectM.waitForLabel('Select Video');
    await this.selectM.selectMediaByName(videoFileName);
    await this.selectM.confirmSelection();
    await this.waitChangeVisualizeMedia(videoFileName, 'video');
  }

  async addAudioClipToolbar(audioFileName: string, audioCaption: string) {
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Audio Clip');
    await this.selectM.waitForLabel('Embed audio');
    await this.selectM.selectMediaByName(audioFileName);
    await this.selectM.confirmOk();
    await this.basicPP.waitForChangesSaved();
    await this.basicPP.fillCaptionAudio(audioCaption);
    await this.waitChangeVisualizeMedia(audioFileName, 'audio');
  }

  async addDescriptionListToolbar(title: string, term: string, definition: string) {
    const descriptionList = new DescriptionListCO(this.page);
    await this.clickOnParagraphAndSelectContent(0, 'More', 'Description List');
    await this.basicPP.waitForChangesSaved();
    await descriptionList.fillTitle(title);
    await this.basicPP.waitForChangesSaved();
    await descriptionList.fillTerm(term);
    await this.basicPP.waitForChangesSaved();
    await descriptionList.fillDefinition(definition);
    await this.waitChangeVisualize(title, term, definition);
  }

  async addConjugationToolbar(
    headColumn1: string,
    headColumn2: string,
    headRow1: string,
    headRow2: string,
    headRow3: string,
  ) {
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Conjugation');
    await this.waitChangeVisualize(headColumn1, headColumn2, headRow1, headRow2, headRow3);
  }

  async addDialogToolbar(dialogTitle: string, dialogSpeaker: string, dialogContent: string) {
    const dialog = new DialogCO(this.page);
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Dialog');
    await dialog.fillTitle(dialogTitle);
    await this.basicPP.waitForChangesSaved();
    await dialog.fillNameSpeaker(1, dialogSpeaker);
    await this.basicPP.waitForChangesSaved();
    await dialog.clickAddButton();
    await this.basicPP.waitForChangesSaved();
    await dialog.fillParagraph(dialogContent);
    await this.waitChangeVisualize(dialogTitle, dialogSpeaker, dialogContent);
  }

  async addTableToolbar(tableCaption: string, cell1: string, cell2: string) {
    const table = new Table(this.page);
    await this.clickOnParagraphAndSelectContent(0, 'Insert Table');
    await this.basicPP.waitForChangesSaved();
    await table.fillCaptionTable(tableCaption);
    await this.basicPP.waitForChangesSaved();
    await table.fillCell(1, 1, cell1);
    await this.basicPP.waitForChangesSaved();
    await table.fillCell(1, 2, cell2);
    await this.waitChangeVisualize(cell1, cell2, tableCaption);
  }

  async addTheoremToolbar(title: string) {
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Theorem');
    await this.waitChangeVisualize(title);
  }

  async addCodeBlockToolbar(codeType: TypeProgrammingLanguage, code: string, caption: string) {
    const cb = new CodeBlockCO(this.page);
    await this.clickOnParagraphAndSelectContent(0, 'Insert...', 'Code (Block)');
    await cb.selectLanguageCode(codeType);
    await cb.fillCodeEditor(code);
    await cb.fillCodeCaption(caption);
    await this.waitChangeVisualize(code, caption);
  }

  async clickOnParagraphAndSelectContent(indexParagraph = 0, ...elements: TypeToolbar[]) {
    await this.basicPP.clickParagraph(indexParagraph);
    for (const element of elements) {
      await this.basicPP.selectElementToolbar(element);
    }
  }

  async fillOnParagraphAndSelectContent(
    text: string,
    indexParagraph = 0,
    ...elements: TypeToolbar[]
  ) {
    await this.basicPP.fillParagraph(text, indexParagraph);
    for (const element of elements) {
      await this.basicPP.selectElementToolbar(element);
    }
  }

  async waitChangeVisualize(...str: string[]) {
    await this.basicPP.waitForChangesSaved();

    const preview = await this.basicPP.clickPreview();
    await preview.verifyContent(...str);
    await preview.close();
  }

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
  async addQuestionActivity(activity: TypeActivity) {
    await this.basicPP.clickInsertButtonIcon();
    await this.basicPP.selectActivity(activity);
    await this.basicPP.waitForChangesSaved();
  }

  async addActivitiesWithQuestions(
    editorTitle: EditorTitle,
    activityType: TypeActivity,
    questionText: string,
  ) {
    this.buildQuestionActivity(editorTitle, activityType, questionText);
    const preview = await this.basicPP.clickPreview();
    await preview.verifyQuestion(questionText);
    await preview.verifyComponent(activityType);
    await preview.close();
  }

  async addActivityDD(questionText: string) {
    this.buildQuestionActivity('Directed Discussion', 'dd', questionText);
  }

  async addActivityDnD(questionText: string) {
    this.buildQuestionActivity('Custom Drag and Drop', 'dnd', questionText);
  }

  async addActivityUpload(questionText: string) {
    this.buildQuestionActivity('File Upload', 'file_aupload', questionText);
  }

  async addActivityCoding(questionText: string) {
    this.buildQuestionActivity('Image Coding', 'coding', questionText);
  }

  async addActivityHotspot(questionText: string) {
    this.buildQuestionActivity('Image Hotspot', 'hotspot', questionText);
  }

  async addActivitiVlab(questionText: string) {
    const vlab = new QuestionVlabCO(this.page);
    await this.addQuestionActivity('vlab');
    await vlab.expectEditorLoaded();
    await vlab.fillQuestion(questionText);
    await vlab.clickAddInputButton();
  }

  async addActivityResponseMulti(questionText: string) {
    const response = new QuestionResponseCO(this.page);
    await this.addQuestionActivity('response_multi');
    await response.expectEditorLoaded();
    await response.fillQuestion(questionText);
    await response.clickAddInputButton();
  }

  async addActivityMulti(questionText: string) {
    const multi = new QuestionMultiCO(this.page);
    await this.addQuestionActivity('multi');
    await multi.expectEditorLoaded();
    await multi.fillQuestion(questionText);
    await multi.clickAddInputButton();
  }

  async addActivityLikert(questionText: string) {
    const likert = new QuestionLikertCO(this.page);
    await this.addQuestionActivity('likert');
    await likert.expectEditorLoaded();
    await likert.fillPrompt(questionText);
  }
  //endregion Activity

  //region Course
  async createNewCourseSection(
    projectName: string,
    projectID: string,
    startDate: Date,
    endDate: Date,
    baseUrl: string,
  ) {
    await this.instructorDB.clickCreateNewSection();
    await this.newCS.step1.searchProject(projectName);
    await this.newCS.step1.clickOnCardProject(projectName);
    await this.newCS.step2.fillCourseName(projectName);
    await this.newCS.step2.fillCourseSectionNumber(projectName);
    await this.newCS.step2.goToNextStep();
    await this.newCS.step3.fillStartDate(startDate);
    await this.newCS.step3.fillEndDate(endDate);
    await this.newCS.step3.submitSection();
    await this.detailCourse.verifyBreadcrumbTrail(projectName);
    await this.detailCourse.verifyCourseSectionID(projectID);
    await this.detailCourse.verifyTitle(projectName);
    await this.detailCourse.verifyUrl(baseUrl, projectID);
  }
  //endregion Course

  //region Private method
  private async buildQuestionActivity(
    editorTitle: EditorTitle,
    activityType: TypeActivity,
    questionText: string,
  ) {
    const activity = new QuestionActivities(this.page, editorTitle);
    this.addQuestionActivity(activityType);
    await activity.expectEditorLoaded();
    await activity.fillQuestion(questionText);
  }
  //endregion Private method
}
