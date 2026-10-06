import { Page } from '@playwright/test';
import { step } from '@core/decoration/step';
import { AdvancedAuthorPO } from '@pom/page/AdvancedAuthorPO';
import { CurriculumTask } from '@tasks/CurriculumTask';
import { HomeTask } from '@tasks/HomeTask';
import { ProjectTask } from '@tasks/ProjectTask';

/**
 * Business workflows for the adaptive Advanced Author editor. Fine-grained
 * editor interactions and assertions live on `editor` (AdvancedAuthorPO).
 */
export class AdvancedAuthorTask {
  readonly editor: AdvancedAuthorPO;
  private readonly homeTask: HomeTask;
  private readonly projectTask: ProjectTask;
  private readonly curriculumTask: CurriculumTask;

  constructor(page: Page) {
    this.editor = new AdvancedAuthorPO(page);
    this.homeTask = new HomeTask(page);
    this.projectTask = new ProjectTask(page);
    this.curriculumTask = new CurriculumTask(page);
  }

  /** Creates an Advanced Author lesson in the project and leaves its editor open. */
  @step('Create Advanced Author lesson "{lessonTitle}" in project "{projectTitle}"')
  async createLesson(projectTitle: string, lessonTitle: string) {
    await this.projectTask.searchAndEnterProject(projectTitle);
    await this.homeTask.enterToCurriculum();
    await this.curriculumTask.createAdaptivePageInAdvancedAuthor(true, lessonTitle);
    await this.editor.waitForEditorLoaded();
    await this.editor.waitForSaves();
  }

  @step('Add screen "{title}"')
  async addScreen(title: string) {
    await this.editor.addScreen(title);
  }

  /** Reloads the editor once every write settled and reopens the given screen. */
  @step('Reload the editor and reopen screen "{title}"')
  async reloadAndOpenScreen(title: string) {
    await this.editor.reloadEditor();
    await this.editor.selectScreen(title);
  }

  @step('Publish the project')
  async publish() {
    await this.editor.waitForSaves();
    await this.homeTask.enterToPublish();
    await this.projectTask.publishProject();
  }
}
