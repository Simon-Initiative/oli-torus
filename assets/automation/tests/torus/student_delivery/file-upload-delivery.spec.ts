import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';
import {
  fileUploadActivity,
  fileUploadError,
  fileUploadInput,
  fileUploadListItems,
  fileUploadSubmit,
} from './support/fileUpload';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './file-upload-delivery.scenario.yaml');
const activityTitle = 'File Upload Practice';

// F1/F4 upload to object storage (S3 in the nightly env, minio locally). Set
// STORAGE_TESTS=1 in an environment with a storage backend to run them; otherwise they
// skip with a visible reason. The oversize/gating negatives (F2/F3) are storage-free.
const storageAvailable = !!process.env.STORAGE_TESTS;

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'file-upload-delivery-student',
    welcomeTitle: 'Hi, File',
    name: 'File',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'file-upload-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'file-upload-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'file-upload-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: Record<string, string>;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    happy: outputs.sections?.file_upload_delivery_section ?? '',
    disabled: outputs.sections?.file_upload_delivery_section_disabled ?? '',
    restore: outputs.sections?.file_upload_delivery_section_restore ?? '',
    oversize: outputs.sections?.file_upload_delivery_section_oversize ?? '',
  };

  Object.values(sections).forEach((section) => expect(section).toBeTruthy());
});

test.describe('file upload delivery', () => {
  test('file upload blocks submitting without a valid file', async ({ homeTask, page }) => {
    await homeTask.login('student');

    await test.step('submit is disabled when no file has been uploaded', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.disabled, activityTitle);
      const activity = fileUploadActivity(page);

      await expect(activity).toBeVisible();
      await expect(fileUploadListItems(activity)).toHaveCount(0);
      await expect(fileUploadSubmit(activity)).toBeDisabled();
    });

    await test.step('a file over the size limit shows the size error and is not added', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.oversize, activityTitle);
      const activity = fileUploadActivity(page);

      await expect(activity).toBeVisible();
      await fileUploadInput(activity).setInputFiles({
        name: 'too-big.txt',
        mimeType: 'text/plain',
        buffer: Buffer.from('this content is well over ten bytes'),
      });

      await expect(fileUploadError(activity)).toHaveText(
        'This file exceeds the maximum allowed file size',
      );
      await expect(fileUploadListItems(activity)).toHaveCount(0);
      await expect(fileUploadSubmit(activity)).toBeDisabled();
    });
  });

  test('file upload accepts a file, records the submission, and restores it @nightly', async ({
    homeTask,
    page,
  }) => {
    test.skip(!storageAvailable, 'requires an object-storage backend (set STORAGE_TESTS=1)');

    await homeTask.login('student');

    await test.step('uploading a file enables submit and shows the received notice', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.happy, activityTitle);
      const activity = fileUploadActivity(page);
      const submitButton = fileUploadSubmit(activity);

      await expect(activity).toBeVisible();
      await expect(submitButton).toBeDisabled();

      await fileUploadInput(activity).setInputFiles({
        name: 'submission.txt',
        mimeType: 'text/plain',
        buffer: Buffer.from('my uploaded work'),
      });

      await expect(fileUploadListItems(activity)).toHaveCount(1);
      await expect(submitButton).toBeEnabled();
      await submitButton.click();

      await expect(activity.getByText('Your response has been received')).toBeVisible();
    });

    await test.step('the uploaded file and received notice persist after reload', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.restore, activityTitle);
      const activity = fileUploadActivity(page);

      await fileUploadInput(activity).setInputFiles({
        name: 'submission.txt',
        mimeType: 'text/plain',
        buffer: Buffer.from('my uploaded work'),
      });
      await expect(fileUploadListItems(activity)).toHaveCount(1);
      await fileUploadSubmit(activity).click();
      await expect(activity.getByText('Your response has been received')).toBeVisible();

      await page.reload({ waitUntil: 'load' });

      const restored = fileUploadActivity(page);
      await expect(fileUploadListItems(restored)).toHaveCount(1);
      await expect(restored.getByText('Your response has been received')).toBeVisible();
    });
  });
});
