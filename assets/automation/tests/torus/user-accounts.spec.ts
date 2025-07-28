import { test } from '@playwright/test';
import { TorusFacade } from '../../src/systems/torus/facade/TorusFacade';
import { FileManager } from '../../src/core/FileManager';
import { USER_TYPES } from '../../src/systems/torus/pom/types/user-type';

let torus: TorusFacade;
const emailAuthor = FileManager.getValueEnv('EMAIL_AUTHOR');
const passAuthor = FileManager.getValueEnv('PASS_AUTHOR');
const emailStuden = FileManager.getValueEnv('EMAIL_STUDENT');
const passStudent = FileManager.getValueEnv('PASS_STUDENT');
const emailInstructor = FileManager.getValueEnv('EMAIL_INSTRUCTOR');
const passInstructor = FileManager.getValueEnv('PASS_INSTRUCTOR');

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
      emailStuden,
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
});
