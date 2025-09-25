import { test } from '@fixture/my-fixture';
import { TorusFacade } from '@facade/TorusFacade';
import { TestData } from './test-data';
import { MEDIA_KIND } from '@pom/types/select-multemedia-types';

const testData = new TestData();
const loginData = testData.loginData;
const projectNames = testData.preconditions.projectNames;
const multiMediaFilesUpload = testData.preconditions.multiMediaFilesUpload;
let torus: TorusFacade;

test.describe('Enviroment configuration', () => {
  test.beforeEach(async ({ page }) => {
    torus = new TorusFacade(page);
    await torus.goToSite();
  });

  test.afterEach(async () => {
    await torus.closeSite();
  });

  for (const name of projectNames) {
    test(`Create project: ${name}`, async ({ utils, page }) => {
      await torus.login(loginData.author.type);

      const exist = await torus.projectExist(name);

      if (!exist) {
        await torus.createNewProjectAsOpen(name);
      }

      await torus.logout();
      await torus.login(loginData.instructor.type, false);
      await torus.verifyProjectAsOpen(name);
    });
  }

  for (const mediaFile of multiMediaFilesUpload) {
    const projectName = mediaFile.projectName;
    const fileName = mediaFile.fileName;
    const kind = mediaFile.type;

    test(`Project name: ${projectName} - Mediafile name: ${fileName}`, async () => {
      await torus.login(loginData.author.type);
      await torus.project().addPageAndEnter('basic-practice', projectName);
      await torus.uploadMediaFile(MEDIA_KIND[kind], fileName);
      await torus.sidebar().clickCourseAuthor();
      await torus.project().deletePage(projectName);
    });
  }
});
