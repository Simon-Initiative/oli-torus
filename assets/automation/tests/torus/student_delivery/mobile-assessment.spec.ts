import { setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { expect } from '@playwright/test';
import { BasicAssessmentPO } from '@pom/course/BasicAssessmentPO';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { randomUUID } from 'node:crypto';
import { buildLoginRecord } from './support/common';

const title = 'Mobile Assessment';
const choiceFeedback = ['Correct. 2 + 2 equals 4.'];
const inputFeedback = ['Correct text.', 'Correct number.', 'Correct choice.'];

for (const viewport of [
  { width: 390, height: 844 },
  { width: 320, height: 568 },
]) {
  test.describe(`basic assessment at ${viewport.width}px @pr @nightly`, () => {
    test.use({ viewport, isMobile: true, hasTouch: true });

    test('student saves answers, submits, and reviews the scored attempt', async ({
      page,
      homeTask,
      seedScenario,
    }) => {
      test.setTimeout(120_000);
      const runId = `-${randomUUID()}`;
      setRuntimeConfig({
        loginData: {
          student: buildLoginRecord(runId, {
            type: 'student',
            role: 'Student',
            emailPrefix: 'mobile-assessment-student',
            welcomeTitle: 'Hi, Mobile',
            name: 'Mobile',
            lastName: 'Student',
          }),
        },
      });
      const assessment = new BasicAssessmentPO(page);

      await test.step('enter the seeded course and start a scored attempt', async () => {
        const scenario = await seedScenario('./mobile-assessment.scenario.yaml', { RUN_ID: runId });
        const outputs = scenario.outputs as { sections?: Record<string, string> };
        const section = outputs.sections?.mobile_assessment_section;
        expect(section, 'seeded mobile assessment section').toBeTruthy();
        await homeTask.login('student');
        await page.goto(`/sections/${section}`);
        const course = new StudentCoursePO(page);
        await course.goToCourseIfPrompted();
        await course.openFirstPage(title);
        await assessment.startAttempt();
        await assessment.expectQuestionText('What is 2 + 2?');
      });

      await test.step('answer both questions and navigate back and forward', async () => {
        await assessment.answerMultipleChoice('4');
        await assessment.nextQuestion(2);
        await assessment.expectQuestionText('Enter the word answer:');
        await assessment.expectQuestionText('Enter the number 42:');
        await assessment.expectQuestionText('Select Correct choice:');
        await assessment.answerInputs('answer', '42', 'Correct choice');
        await assessment.previousQuestion(1);
        await assessment.expectMultipleChoiceAnswer('4');
        await assessment.nextQuestion(2);
        await assessment.expectInputAnswers('answer', '42', 'Correct choice');
      });

      await test.step('reload the active attempt and verify saved responses', async () => {
        await page.reload();
        await assessment.expectQuestion(1);
        await assessment.expectMultipleChoiceAnswer('4');
        await assessment.nextQuestion(2);
        await assessment.expectInputAnswers('answer', '42', 'Correct choice');
      });

      await test.step('submit responses, check feedback, and confirm completion', async () => {
        await assessment.submitQuestion(inputFeedback);
        await assessment.previousQuestion(1);
        await assessment.submitQuestion(choiceFeedback);
        await assessment.nextQuestion(2);
        await assessment.finishAttempt(4, 4);
      });

      await test.step('review the submitted answers and permitted feedback', async () => {
        await assessment.reviewAttempt([...choiceFeedback, ...inputFeedback]);
        await assessment.expectMultipleChoiceAnswer('4');
        await assessment.expectInputAnswers('answer', '42', 'Correct choice');
      });
    });
  });
}
