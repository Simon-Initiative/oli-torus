import { test } from '@fixture/my-fixture';
import { TestData } from './test-data';

const testData = new TestData();
const projectNames = testData.preconditions.projectNames;
const multiMediaFilesUpload = testData.preconditions.multiMediaFilesUpload;
const bibliography = testData.bibliography;

test.describe('Enviroment configuration', () => {
  for (const name of projectNames) {
    test(`Create project: ${name}`, async ({ homeTask, projectTask }) => {
      await homeTask.login('author');
      const exist = await projectTask.projectExist(name);

      if (!exist) {
        await test.step('Create new project', async () => {
          await projectTask.createNewProjectAsOpen(name);
          await homeTask.enterToPublish();
          await projectTask.publishProject();
        });
      }
      await homeTask.logout();
      await homeTask.login('instructor');
      await projectTask.verifyProjectAsOpen(name);
    });
  }

  for (const mediaFile of multiMediaFilesUpload) {
    const projectName = mediaFile.projectName;
    const fileName = mediaFile.fileName;
    const kind = mediaFile.type;

    test(`Project name: ${projectName} - Mediafile name: ${fileName}`, async ({
      homeTask,
      curriculumTask,
      projectTask,
    }) => {
      await homeTask.login('author');
      await projectTask.searchAndEnterProject(projectName);

      await test.step('Add a page to the project', async () => {
        await homeTask.enterToCurriculum();
        await curriculumTask.addPageAndEnter('basic-practice');
      });

      await curriculumTask.uploadMediaFile(kind as 'image' | 'audio' | 'video', fileName);
      await homeTask.enterToCourseAuthor();
      await projectTask.searchAndEnterProject(projectName);
      await homeTask.enterToCurriculum();
      await curriculumTask.deletePage();
    });
  }

  test(`Add a bibliography to the project name: ${bibliography.projectName}`, async ({
    homeTask,
    projectTask,
  }) => {
    await homeTask.login('author');
    await projectTask.searchAndEnterProject(bibliography.projectName);
    await homeTask.enterToBibliography();
    await projectTask.addBibliographyToProject(bibliography.bibtext);
  });
});
