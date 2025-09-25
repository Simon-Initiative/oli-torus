import { test } from '@playwright/test';
import { TorusFacade } from '@facade/TorusFacade';
import { TestData } from '../test-data';

const testData = new TestData();
const loginData = testData.loginData;
let torus: TorusFacade;

test.describe('User Accounts', () => {
  test.beforeEach(async ({ page }) => {
    torus = new TorusFacade(page);
    await torus.goToSite();
  });

  test.afterEach(async () => {
    await torus.closeSite();
  });

  test('Sign into an authoring account with valid details', async () => {
    await torus.login(loginData.author.type, true);
  });

  test('Sign in as a student with valid details', async () => {
    await torus.login(loginData.student.type, true);
  });

  test('Sign in as an instructor with valid details', async () => {
    await torus.login(loginData.instructor.type, true);
  });

  test('As an administrator, go to a users profile, allow the user to create sections, and then, as that user, log in and verify you can create sections', async () => {
    await torus.login('administrator', true);
    await torus.canCreateSections(
      loginData.student.email,
      `${loginData.student.last_name}, ${loginData.student.name}`,
    );
    await torus.login(loginData.student.type, false);
    await torus.verifyCanCreateSections('New course set up');
  });
});
