import { test } from '@fixture/my-fixture';
import { TestData } from '../test-data';

const testData = new TestData();
const loginData = testData.loginData;

test.describe('User Accounts', () => {
  test('Sign into an authoring account with valid details', async ({ homeTask }) => {
    await homeTask.login('author');
  });

  test('Sign in as a student with valid details', async ({ homeTask }) => {
    await homeTask.login('student');
  });

  test('Sign in as an instructor with valid details', async ({ homeTask }) => {
    await homeTask.login('instructor');
  });

  test('As an administrator, go to a users profile, allow the user to create sections, and then, as that user, log in and verify you can create sections', async ({
    homeTask,
    administrationTask,
    studentTask,
  }) => {
    const email = loginData.student.email;
    const lastName = loginData.student.last_name;
    const name = loginData.student.name;

    await homeTask.login('administrator');
    await administrationTask.canCreateSections(email, `${lastName}, ${name}`);
    await homeTask.logout(true);
    await homeTask.login('student');
    await studentTask.verifyCanCreateSections('New course set up');
  });
});
