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
    await torus.log_in(
      loginData.author.type,
      loginData.author.pageTitle,
      loginData.author.role,
      loginData.author.welcomeText,
      loginData.author.email,
      loginData.author.pass,
      loginData.author.header,
    );
  });

  test('Sign in as a student with valid details', async () => {
    await torus.log_in(
      loginData.student.type,
      loginData.student.pageTitle,
      loginData.student.role,
      loginData.student.welcomeText,
      loginData.student.email,
      loginData.student.pass,
      loginData.student.name,
    );
  });

  test('Sign in as an instructor with valid details', async () => {
    await torus.log_in(
      loginData.instructor.type,
      loginData.instructor.pageTitle,
      loginData.instructor.role,
      loginData.instructor.welcomeText,
      loginData.instructor.email,
      loginData.instructor.pass,
      loginData.instructor.header,
    );
  });

  test('As an administrator, go to a users profile, allow the user to create sections, and then, as that user, log in and verify you can create sections', async () => {
    await torus.log_in(
      loginData.author.type,
      loginData.author.pageTitle,
      loginData.author.role,
      loginData.author.welcomeText,
      loginData.admin.email,
      loginData.admin.pass,
      loginData.author.header,
    );
    await torus.canCreateSections(loginData.student.email, `Argos, ${loginData.student.name}`);
    await torus.log_in(
      loginData.student.type,
      loginData.student.pageTitle,
      loginData.student.role,
      loginData.student.welcomeText,
      loginData.student.email,
      loginData.student.pass,
      loginData.student.name,
      false,
    );
    await torus.verifyCanCreateSections('New course set up');
  });
});
