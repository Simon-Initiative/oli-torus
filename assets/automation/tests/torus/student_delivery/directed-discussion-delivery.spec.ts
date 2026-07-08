import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';
import {
  directedDiscussionActivity,
  newPostTextarea,
  postButton,
} from './support/directedDiscussion';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './directed-discussion-delivery.scenario.yaml');
const activityTitle = 'Discussion Practice';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'dd-delivery-student',
    welcomeTitle: 'Hi, Discussion',
    name: 'Discussion',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'dd-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'dd-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'dd-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: Record<string, string>;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    post: outputs.sections?.dd_delivery_section ?? '',
    gating: outputs.sections?.dd_delivery_section_gating ?? '',
    restore: outputs.sections?.dd_delivery_section_restore ?? '',
    wordLimit: outputs.sections?.dd_delivery_section_wordlimit ?? '',
  };

  Object.values(sections).forEach((section) => expect(section).toBeTruthy());
});

test.describe('directed discussion delivery', () => {
  test('directed discussion gates the Post control by length and word limit', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    await test.step('Post is hidden until content is entered and disabled below 4 characters', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.gating, activityTitle);
      const activity = directedDiscussionActivity(page);
      const textarea = newPostTextarea(activity);

      await expect(activity).toBeVisible();
      await expect(postButton(activity)).toHaveCount(0);

      await textarea.fill('abc');
      await expect(postButton(activity)).toBeDisabled();

      await textarea.fill('abcd');
      await expect(postButton(activity)).toBeEnabled();
    });

    await test.step('a post over the word limit shows the warning and disables Post', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.wordLimit, activityTitle);
      const activity = directedDiscussionActivity(page);

      await newPostTextarea(activity).fill('one two three four');

      await expect(activity.getByText(/Over max word limit/)).toBeVisible();
      await expect(postButton(activity)).toBeDisabled();
    });
  });

  test('a student can post to the discussion and meet the participation requirement', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    await test.step('posting a message adds it to the thread and satisfies participation', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.post, activityTitle);
      const activity = directedDiscussionActivity(page);
      const message = 'Hello everyone, my first discussion post';

      await expect(activity).toBeVisible();
      await expect(activity.getByText('0/1')).toBeVisible();

      await newPostTextarea(activity).fill(message);
      await expect(postButton(activity)).toBeEnabled();
      await postButton(activity).click();

      await expect(activity.getByText(message)).toBeVisible();
      await expect(activity.getByText('✅')).toBeVisible();
    });
  });

  test('directed discussion restores the posted message after reload', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    await test.step('a posted message is still shown after reloading the page', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.restore, activityTitle);
      const activity = directedDiscussionActivity(page);
      const message = 'This discussion post should persist across reload';

      await newPostTextarea(activity).fill(message);
      await postButton(activity).click();
      await expect(activity.getByText(message)).toBeVisible();

      await page.reload({ waitUntil: 'load' });

      await expect(directedDiscussionActivity(page).getByText(message)).toBeVisible();
    });
  });
});
