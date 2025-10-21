import { test as base } from '@playwright/test';
import { Utils } from '@core/Utils';
import { Verifier } from '@core/verify/Verifier';
import { FileManager } from '@core/FileManager';
import { AdministrationTask } from '@tasks/AdministrationTask';
import { CurriculumTask } from '@tasks/CurriculumTask';
import { HomeTask } from '@tasks/HomeTask';
import { ProjectTask } from '@tasks/ProjectTask';
import { StudentTask } from '@tasks/StudentTask';

const closeBrowser = FileManager.getValueEnv('AUTO_CLOSE_BROWSER') === 'true';

type MyFixtures = {
  forEachTest: void;
  utils: Utils;
  verifier: Verifier;
  administrationTask: AdministrationTask;
  curriculumTask: CurriculumTask;
  homeTask: HomeTask;
  projectTask: ProjectTask;
  studentTask: StudentTask;
};

export const test = base.extend<MyFixtures>({
  forEachTest: [
    async ({ homeTask }, use) => {
      await homeTask.goToSite();
      await use();

      if (closeBrowser) {
        await homeTask.closeSite();
      }
    },
    { auto: true, title: '🔄 Before/After Each' },
  ],
  utils: [
    async ({ page }, use) => {
      await use(new Utils(page));
    },
    { title: '🛠️ Utils' },
  ],

  administrationTask: [
    async ({ page }, use) => {
      await use(new AdministrationTask(page));
    },
    { title: '🏢 Administration Task' },
  ],
  curriculumTask: [
    async ({ page }, use) => {
      await use(new CurriculumTask(page));
    },
    { title: '📚 Curriculum Task' },
  ],
  homeTask: [
    async ({ page }, use) => {
      await use(new HomeTask(page));
    },
    { title: '🏠 Home Task' },
  ],
  projectTask: [
    async ({ page }, use) => {
      await use(new ProjectTask(page));
    },
    { title: '📂 Project Task' },
  ],
  studentTask: [
    async ({ page }, use) => {
      await use(new StudentTask(page));
    },
    { title: '🎓 Student Task' },
  ],
});
