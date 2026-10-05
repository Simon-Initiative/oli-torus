import { Page } from '@playwright/test';
import { step } from '@core/decoration/step';
import { SimpleAuthorPO, SimpleAuthorScreenType } from '@pom/page/SimpleAuthorPO';
import { CurriculumTask } from '@tasks/CurriculumTask';
import { HomeTask } from '@tasks/HomeTask';
import { ProjectTask } from '@tasks/ProjectTask';

/**
 * Business workflows for the adaptive Simple Author editor. Fine-grained
 * editor interactions and assertions live on `editor` (SimpleAuthorPO).
 */
export class SimpleAuthorTask {
  readonly editor: SimpleAuthorPO;
  private readonly homeTask: HomeTask;
  private readonly projectTask: ProjectTask;
  private readonly curriculumTask: CurriculumTask;

  constructor(private readonly page: Page) {
    this.editor = new SimpleAuthorPO(page);
    this.homeTask = new HomeTask(page);
    this.projectTask = new ProjectTask(page);
    this.curriculumTask = new CurriculumTask(page);
  }

  /** Creates a Simple Author lesson in the project and returns its editor URL. */
  @step('Create Simple Author lesson "{lessonTitle}" in project "{projectTitle}"')
  async createLesson(projectTitle: string, lessonTitle: string) {
    await this.projectTask.searchAndEnterProject(projectTitle);
    await this.homeTask.enterToCurriculum();
    await this.curriculumTask.createAdaptivePageInSimpleAuthor(true, lessonTitle);
    await this.editor.waitForEditorLoaded();
    await this.editor.waitForSaves();

    return this.page.url();
  }

  @step('Open Simple Author lesson in the Screen Panel')
  async openLesson(editorUrl: string) {
    await this.editor.openEditor(editorUrl);
    await this.editor.switchToScreenPanel();
  }

  @step('Add "{type}" screen "{title}"')
  async addScreen(title: string, type: SimpleAuthorScreenType) {
    await this.editor.addScreen(title, type);
  }

  /** Reloads the editor once every write settled and reopens the given screen. */
  @step('Reload the editor and reopen screen "{title}"')
  async reloadAndOpenScreen(title: string) {
    await this.editor.reloadEditor();
    await this.editor.switchToScreenPanel();
    await this.editor.selectScreen(title);
  }

  @step('Publish the project')
  async publish() {
    await this.editor.waitForSaves();
    await this.homeTask.enterToPublish();
    await this.projectTask.publishProject();
  }
}
