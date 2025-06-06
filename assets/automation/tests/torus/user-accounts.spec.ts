import { test } from '@playwright/test';
import { TorusFacade } from '@facade/TorusFacade';
import { FileManager } from '@core/FileManager';
import { USER_TYPES } from '@pom/types/user-type';

let torus: TorusFacade;
const emailAuthor = FileManager.getValueEnv('EMAIL_AUTHOR');
const passAuthor = FileManager.getValueEnv('PASS_AUTHOR');
const emailStudent = FileManager.getValueEnv('EMAIL_STUDENT');
const nameStudent = FileManager.getValueEnv('NAME_STUDENT');
const passStudent = FileManager.getValueEnv('PASS_STUDENT');
const emailInstructor = FileManager.getValueEnv('EMAIL_INSTRUCTOR');
const passInstructor = FileManager.getValueEnv('PASS_INSTRUCTOR');
const emailAdmin = FileManager.getValueEnv('EMAIL_ADMIN');
const passAdmin = FileManager.getValueEnv('PASS_ADMIN');

test.describe('User Accounts', () => {
  test.beforeEach(async ({ page }) => {
    torus = new TorusFacade(page);
    await torus.goToSite();
  });

  test.afterEach(async () => {
    await torus.closeSite();
  });

  test('Sign into an authoring account with valid details', async () => {
    await torus.login(
      USER_TYPES.AUTHOR,
      'OLI Torus',
      'Course Author',
      'Welcome to OLI Torus',
      emailAuthor,
      passAuthor,
      'Course Author',
    );
  });

  test('Sign in as a student with valid details', async () => {
    await torus.login(
      USER_TYPES.STUDENT,
      'OLI Torus',
      'Student',
      'Welcome to OLI Torus',
      emailStudent,
      passStudent,
      'Victoria Student',
    );
  });

  test('Sign in as an instructor with valid details', async () => {
    await torus.login(
      USER_TYPES.INSTRUCTOR,
      'Sign in',
      'Instructor',
      'Welcome to OLI Torus',
      emailInstructor,
      passInstructor,
      'Instructor Dashboard',
    );
  });

  test('As an administrator, go to a users profile, allow the user to create sections, and then, as that user, log in and verify you can create sections', async () => {
    await torus.login(
      USER_TYPES.AUTHOR,
      'OLI Torus',
      'Course Author',
      'Welcome to OLI Torus',
      emailAdmin,
      passAdmin,
      'Course Author',
    );
    await torus.canCreateSections(emailStudent, `Argos, ${nameStudent}`);
    await torus.login(
      USER_TYPES.STUDENT,
      'OLI Torus',
      'Student',
      'Welcome to OLI Torus',
      emailStudent,
      passStudent,
      nameStudent,
      false,
    );
    await torus.verifyCanCreateSections('New course set up');
  });
});
