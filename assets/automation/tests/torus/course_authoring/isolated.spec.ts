import { test } from '@fixture/my-fixture';
import { TestData } from '../test-data';
import { TYPE_ACTIVITY, TypeActivity } from '@pom/types/type-activity';

const testData = new TestData();
const questionText = 'Question test?';

test.describe('Course authoring', () => {
  test('Log in as an author and create a new course project with valid details, set the Publishing Visibility as Open', async ({
    homeTask,
    projectTask,
    curriculumTask,
    utils,
  }) => {
    const startDate = new Date();
    const endDate = new Date();
    endDate.setFullYear(endDate.getFullYear() + 1);

    await homeTask.login('author');

  });

});
