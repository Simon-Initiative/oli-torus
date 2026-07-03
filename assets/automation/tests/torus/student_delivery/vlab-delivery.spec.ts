import { expect, type Locator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';
import { getVlabHiddenValue, sendVlabSelection } from './support/vlab';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './vlab-delivery.scenario.yaml');
const activityTitle = 'Vlab Practice';

const stems = {
  numeric: 'Provide the numeric virtual lab value:',
  dropdown: 'Select the dropdown virtual lab value:',
  message: 'Capture the selected flask volume from the virtual lab.',
};

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'vlab-delivery-student',
    welcomeTitle: 'Hi, Vlab',
    name: 'Vlab',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'vlab-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'vlab-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'vlab-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: Record<string, string>;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    numericCorrect: outputs.sections?.vlab_delivery_section_numeric_correct ?? '',
    numericIncorrect: outputs.sections?.vlab_delivery_section_numeric_incorrect ?? '',
    numericReset: outputs.sections?.vlab_delivery_section_numeric_reset ?? '',
    numericSaved: outputs.sections?.vlab_delivery_section_numeric_saved ?? '',
    dropdownCorrect: outputs.sections?.vlab_delivery_section_dropdown_correct ?? '',
    dropdownIncorrect: outputs.sections?.vlab_delivery_section_dropdown_incorrect ?? '',
    messageCorrect: outputs.sections?.vlab_delivery_section_message_correct ?? '',
    messageIncorrect: outputs.sections?.vlab_delivery_section_message_incorrect ?? '',
    messageRestore: outputs.sections?.vlab_delivery_section_message_restore ?? '',
  };

  Object.values(sections).forEach((section) => expect(section).toBeTruthy());
});

test.describe('vlab delivery', () => {
  test('numeric vlab variants evaluate and persist as expected', async ({ homeTask, page }) => {
    await homeTask.login('student');

    // Numeric input: correct answer path.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.numericCorrect,
      activityTitle,
    );
    let activity = vlabActivity(page, stems.numeric);
    let textbox = vlabTextbox(activity);
    let submitButton = vlabSubmitButton(activity);

    await expect(activity).toBeVisible();
    await expect(textbox).toBeVisible();
    await expect(textbox).toBeEditable();
    await textbox.fill('42');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. You entered the expected numeric value.',
    );

    // Numeric input: incorrect answer path.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.numericIncorrect,
      activityTitle,
    );
    activity = vlabActivity(page, stems.numeric);
    textbox = vlabTextbox(activity);
    submitButton = vlabSubmitButton(activity);

    await expect(textbox).toBeVisible();
    await expect(textbox).toBeEditable();
    await textbox.fill('7');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );

    // Numeric input: reset clears evaluation.
    await openStudentDeliveryPracticeForLoggedInStudent(page, sections.numericReset, activityTitle);
    activity = vlabActivity(page, stems.numeric);
    textbox = vlabTextbox(activity);
    submitButton = vlabSubmitButton(activity);
    const resetButton = vlabResetButton(activity);

    await expect(textbox).toBeVisible();
    await expect(textbox).toBeEditable();
    await textbox.fill('42');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await resetButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toHaveCount(0);
    await expect(activity.locator('.evaluation.feedback.incorrect')).toHaveCount(0);
    await expect(textbox).toHaveValue('');

    // Numeric input: saved value restores before submit.
    await openStudentDeliveryPracticeForLoggedInStudent(page, sections.numericSaved, activityTitle);
    activity = vlabActivity(page, stems.numeric);
    textbox = vlabTextbox(activity);

    await expect(textbox).toBeVisible();
    await expect(textbox).toBeEditable();
    await textbox.fill('42');
    await page.reload({ waitUntil: 'load' });

    activity = vlabActivity(page, stems.numeric);
    textbox = vlabTextbox(activity);

    await expect(textbox).toHaveValue('42');
  });

  test('dropdown vlab variants evaluate the expected choices', async ({ homeTask, page }) => {
    await homeTask.login('student');

    // Dropdown input: correct choice path.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.dropdownCorrect,
      activityTitle,
    );
    let activity = vlabActivity(page, stems.dropdown);
    let dropdown = vlabDropdown(activity);
    let submitButton = vlabSubmitButton(activity);

    await expect(activity).toBeVisible();
    await expect(dropdown).toBeVisible();
    await expect(dropdown).toBeEnabled();
    await dropdown.selectOption('vlab_dropdown_a');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. You selected the expected dropdown value.',
    );

    // Dropdown input: incorrect choice path.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.dropdownIncorrect,
      activityTitle,
    );
    activity = vlabActivity(page, stems.dropdown);
    dropdown = vlabDropdown(activity);
    submitButton = vlabSubmitButton(activity);

    await expect(dropdown).toBeVisible();
    await expect(dropdown).toBeEnabled();
    await dropdown.selectOption('vlab_dropdown_b');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );
  });

  test('vlab message variants capture iframe-driven values and restore them', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    // Vlab message input: correct iframe-derived value.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.messageCorrect,
      activityTitle,
    );
    let activity = vlabActivity(page, stems.message);
    let submitButton = vlabSubmitButton(activity);

    await sendVlabSelection(activity, flaskXml(42));
    await expect(getVlabHiddenValue(activity)).resolves.toBe('42');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.correct')).toContainText(
      'Correct. The virtual lab value was captured.',
    );

    // Vlab message input: incorrect iframe-derived value.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.messageIncorrect,
      activityTitle,
    );
    activity = vlabActivity(page, stems.message);
    submitButton = vlabSubmitButton(activity);

    await sendVlabSelection(activity, flaskXml(7));
    await expect(getVlabHiddenValue(activity)).resolves.toBe('7');
    await submitButton.click();

    await expect(activity.locator('.evaluation.feedback.incorrect')).toBeVisible();
    await expect(activity.locator('.evaluation.feedback.incorrect')).toContainText(
      'Incorrect. Try again.',
    );

    // Vlab message input: evaluated value restores after reload.
    await openStudentDeliveryPracticeForLoggedInStudent(
      page,
      sections.messageRestore,
      activityTitle,
    );
    activity = vlabActivity(page, stems.message);
    submitButton = vlabSubmitButton(activity);

    await sendVlabSelection(activity, flaskXml(42));
    await submitButton.click();
    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();

    await page.reload({ waitUntil: 'load' });

    activity = vlabActivity(page, stems.message);

    await expect(getVlabHiddenValue(activity)).resolves.toBe('42');
    await expect(activity.locator('.evaluation.feedback.correct')).toBeVisible();
  });
});

function vlabActivity(page: Page, stem: string) {
  return page
    .locator('.activity.mc-activity')
    .filter({ has: page.getByText(stem, { exact: false }) })
    .first();
}

function vlabTextbox(activity: Locator) {
  return activity.getByRole('textbox', { name: 'answer submission textbox' }).first();
}

function vlabDropdown(activity: Locator) {
  return activity.getByRole('combobox', { name: 'Select answer' }).first();
}

function vlabSubmitButton(activity: Locator) {
  return activity.getByRole('button', { name: 'submit', exact: true });
}

function vlabResetButton(activity: Locator) {
  return activity.getByRole('button', { name: 'reset', exact: true });
}

function flaskXml(volume: number) {
  return `
    <flask>
      <volume>${volume}</volume>
      <temp>298</temp>
      <species>
        <id>1</id>
        <moles>1</moles>
        <mass>1</mass>
      </species>
    </flask>
  `.trim();
}
