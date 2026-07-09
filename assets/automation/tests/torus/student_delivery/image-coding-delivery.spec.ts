import { expect, type Locator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';
import {
  expectImageCodingSource,
  getImageCodingSource,
  imageCodingResultCanvas,
  runImageCodingUntilCanvasReady,
  runImageCodingUntilTextReady,
  setImageCodingSource,
} from './support/imageCoding';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './image-coding-delivery.scenario.yaml');
const textActivityTitle = 'Image Coding Practice';
const imageActivityTitle = 'Image Coding Image Practice';
const tableActivityTitle = 'Image Coding Table Practice';

const activityStems = {
  text: 'Run the code and submit the correct output.',
  image: 'Load the image resource and submit the expected rendered result.',
  table: 'Load the table resource and submit the expected value.',
};

const imageCodingImagePrograms = {
  exact: ['image = new SimpleImage("image_coding_sample.png");', 'print(image);'].join('\n'),
  slightDifference: [
    'image = new SimpleImage("image_coding_sample.png");',
    'pixel = image.getPixel(0, 0);',
    'pixel.setRed(pixel.getRed() + 1);',
    'print(image);',
  ].join('\n'),
  largeDifference: [
    'image = new SimpleImage("image_coding_sample.png");',
    'var width = image.getWidth();',
    'var height = image.getHeight();',
    'var targetWidth = Math.floor(width * 0.3);',
    'for (var y = 0; y < height; y += 1) {',
    '  for (var x = 0; x < targetWidth; x += 1) {',
    '    pixel = image.getPixel(x, y);',
    '    pixel.setRed(255);',
    '    pixel.setGreen(0);',
    '    pixel.setBlue(255);',
    '  }',
    '}',
    'print(image);',
  ].join('\n'),
};

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'image-coding-delivery-student',
    welcomeTitle: 'Hi, Image Coding',
    name: 'Image Coding',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'image-coding-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'image-coding-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'image-coding-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: Record<string, string>;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    correct: outputs.sections?.image_coding_delivery_section_correct ?? '',
    incorrect: outputs.sections?.image_coding_delivery_section_incorrect ?? '',
    error: outputs.sections?.image_coding_delivery_section_error ?? '',
    reset: outputs.sections?.image_coding_delivery_section_reset ?? '',
    restore: outputs.sections?.image_coding_delivery_section_restore ?? '',
    savedCode: outputs.sections?.image_coding_delivery_section_saved_code ?? '',
  };

  Object.values(sections).forEach((section) => expect(section).toBeTruthy());
});

test.describe('image coding delivery', () => {
  test('image coding evaluation variants show the expected outcomes', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');
    await test.step('image coding: edited code evaluates as correct', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.correct,
        textActivityTitle,
      );
      const activity = imageCodingActivity(page, activityStems.text);
      const output = imageCodingOutput(activity);
      const runButton = imageCodingRunButton(activity);
      const submitButton = imageCodingSubmitButton(activity);

      await expect(activity).toBeVisible();
      await expect(submitButton).toBeDisabled();
      await expect(activity.getByText('Output:')).toBeVisible();

      await setImageCodingSource(activity, 'print("correct")');
      await runButton.click();

      await expect(output).toContainText('correct');
      await expect(submitButton).toBeEnabled();
      await submitButton.click();

      await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
      await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
        'Correct. You produced the expected output.',
      );
      await expect(runButton).toBeDisabled();
      await expect(submitButton).toBeDisabled();
    });

    await test.step('image coding: default code evaluates as incorrect', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.incorrect,
        textActivityTitle,
      );
      const activity = imageCodingActivity(page, activityStems.text);
      const output = imageCodingOutput(activity);
      const runButton = imageCodingRunButton(activity);
      const submitButton = imageCodingSubmitButton(activity);

      await expect(activity).toBeVisible();
      await expect(submitButton).toBeDisabled();
      await runButton.click();

      await expect(output).toContainText('wrong');
      await expect(submitButton).toBeEnabled();
      await submitButton.click();

      await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
      await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
        'Incorrect. Try again.',
      );
      await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);
    });

    await test.step('image coding: execution errors still allow incorrect submission feedback', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.error, textActivityTitle);
      const activity = imageCodingActivity(page, activityStems.text);
      const runButton = imageCodingRunButton(activity);
      const submitButton = imageCodingSubmitButton(activity);
      const errorMessage = activity.locator('span', { hasText: 'Error:' }).first();

      await setImageCodingSource(activity, 'print(missingVariable)');
      await runButton.click();

      await expect(errorMessage).toBeVisible();
      await expect(submitButton).toBeEnabled();
      await submitButton.click();

      await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
      await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
        'Incorrect. Try again.',
      );
    });

    await test.step('image coding: image processing submissions evaluate rendered output', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.correct,
        imageActivityTitle,
      );
      const activity = imageCodingActivity(page, activityStems.image);
      const submitButton = imageCodingSubmitButton(activity);
      const resetButton = imageCodingResetButton(activity);
      const resultCanvas = imageCodingResultCanvas(activity);

      await expect(activity).toBeVisible();
      await expect(submitButton).toBeDisabled();

      await test.step('image coding image: exact image match evaluates correctly', async () => {
        await setImageCodingSource(activity, imageCodingImagePrograms.exact);
        await runImageCodingUntilCanvasReady(activity, resultCanvas);
        await expect(submitButton).toBeEnabled();
        await submitButton.click();
        await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
        await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
          'Congratulations! you found the GOAT',
        );
      });

      await test.step(
        'image coding image: slight pixel difference stays within tolerance',
        async () => {
          await resetButton.click();
          await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);
          await setImageCodingSource(activity, imageCodingImagePrograms.slightDifference);
          await runImageCodingUntilCanvasReady(activity, resultCanvas);
          await expect(submitButton).toBeEnabled();
          await submitButton.click();
          await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
        },
      );

      await test.step(
        'image coding image: large visual difference evaluates incorrectly',
        async () => {
          await resetButton.click();
          await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);
          await setImageCodingSource(activity, imageCodingImagePrograms.largeDifference);
          await runImageCodingUntilCanvasReady(activity, resultCanvas);
          await expect(submitButton).toBeEnabled();
          await submitButton.click();

          await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
          await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
            'Incorrect. Try again.',
          );
        },
      );
    });

    await test.step('image coding: table processing submissions can load csv resources', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.correct,
        tableActivityTitle,
      );
      const activity = imageCodingActivity(page, activityStems.table);
      const output = imageCodingOutput(activity);
      const submitButton = imageCodingSubmitButton(activity);
      const resetButton = imageCodingResetButton(activity);

      await expect(activity).toBeVisible();
      await expect(submitButton).toBeDisabled();

      // Table-processing correct path: read the expected csv field through SimpleTable.
      await setImageCodingSource(
        activity,
        'var table = new SimpleTable("image_coding_table.csv"); print(table.getRow(1).getField("value"))',
      );
      await runImageCodingUntilTextReady(activity, output, '7');
      await expect(output).toContainText('7');
      await expect(submitButton).toBeEnabled();
      await submitButton.click();
      await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();

      // Table-processing incorrect path: reset, then replace the code with one that prints the wrong field.
      await resetButton.click();
      await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);

      await setImageCodingSource(
        activity,
        'var table = new SimpleTable("image_coding_table.csv"); print(table.getRow(0).getField("name"))',
      );
      await runImageCodingUntilTextReady(activity, output, 'alpha');
      await expect(output).toContainText('alpha');
      await submitButton.click();

      await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
      await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
        'Incorrect. Try again.',
      );
    });
  });

  test('image coding persistence variants support reset and restore', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');
    await test.step('image coding: reset clears evaluated state and output', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(page, sections.reset, textActivityTitle);
      const activity = imageCodingActivity(page, activityStems.text);
      const output = imageCodingOutput(activity);
      const runButton = imageCodingRunButton(activity);
      const submitButton = imageCodingSubmitButton(activity);
      const resetButton = imageCodingResetButton(activity);

      await setImageCodingSource(activity, 'print("correct")');
      await runButton.click();
      await submitButton.click();

      await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
      await expect(resetButton).toBeVisible();
      await resetButton.click();

      await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);
      await expect(activity.locator('.evaluation.feedback.incorrect')).toHaveCount(0);
      await expect(output).toHaveCount(0);
      await expect(runButton).toBeEnabled();
      await expect(submitButton).toBeDisabled();
    });

    await test.step('image coding: evaluated correct state restores after reload', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.restore,
        textActivityTitle,
      );
      let activity = imageCodingActivity(page, activityStems.text);
      let output = imageCodingOutput(activity);
      let runButton = imageCodingRunButton(activity);
      let submitButton = imageCodingSubmitButton(activity);

      await setImageCodingSource(activity, 'print("correct")');
      await runButton.click();
      await submitButton.click();

      await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
      await page.reload({ waitUntil: 'load' });

      activity = imageCodingActivity(page, activityStems.text);
      output = imageCodingOutput(activity);
      runButton = imageCodingRunButton(activity);
      submitButton = imageCodingSubmitButton(activity);

      await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
      await expect(output).toContainText('correct');
      await expect(runButton).toBeDisabled();
      await expect(submitButton).toBeDisabled();
    });

    await test.step('image coding: saved code restores before submission', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.savedCode,
        textActivityTitle,
      );
      let activity = imageCodingActivity(page, activityStems.text);

      await setImageCodingSource(activity, 'print("correct")');
      await expect(getImageCodingSource(activity)).resolves.toBe('print("correct")');

      await page.reload({ waitUntil: 'load' });

      activity = imageCodingActivity(page, activityStems.text);

      await expectImageCodingSource(activity, 'print("correct")');
      await expect(imageCodingSubmitButton(activity)).toBeDisabled();
    });
  });
});

function imageCodingActivity(page: Page, stem: string) {
  return page
    .locator('.activity.short-answer-activity')
    .filter({ has: page.getByText(stem, { exact: true }) })
    .first();
}

function imageCodingOutput(activity: Locator) {
  return activity.locator('div[style*="white-space: pre-wrap;"] p').first();
}

function imageCodingRunButton(activity: Locator) {
  return activity.getByRole('button', { name: 'Run', exact: true });
}

function imageCodingSubmitButton(activity: Locator) {
  return activity.getByRole('button', { name: 'Submit', exact: true });
}

function imageCodingResetButton(activity: Locator) {
  return activity.getByRole('button', { name: 'Reset', exact: true });
}
