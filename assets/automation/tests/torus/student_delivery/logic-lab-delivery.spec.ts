import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import { openStudentDeliveryPracticeForLoggedInStudent } from './support/common';
import {
  logicLabIframe,
  requestLogicLabLoad,
  sendLogicLabSave,
  sendLogicLabScore,
  type LogicLabSaveState,
} from './support/logicLab';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './logic-lab-delivery.scenario.yaml');
const activityTitle = 'Logic Lab Practice';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'logic-lab-delivery-student',
    welcomeTitle: 'Hi, Logic',
    name: 'Logic',
    lastName: 'Lab Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'logic-lab-delivery-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'logic-lab-delivery-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'logic-lab-delivery-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sections: Record<string, string>;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sections = {
    saveRestore: outputs.sections?.logic_lab_delivery_section_save_restore ?? '',
    completeScore: outputs.sections?.logic_lab_delivery_section_complete_score ?? '',
    incompleteScore: outputs.sections?.logic_lab_delivery_section_incomplete_score ?? '',
  };

  Object.values(sections).forEach((section) => expect(section).toBeTruthy());
});

/**
 * These tests validate Torus-side delivery integration for Logic Lab by
 * simulating the save/score/load postMessage contract that the embedded lab
 * uses. They do not currently prove that the external LogicLab runtime itself
 * loaded successfully inside the iframe.
 */
test.describe('logic lab delivery', () => {
  test('logic lab draft state saves and restores through load messages', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    await test.step('logic lab renders an iframe configured for delivery mode', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.saveRestore,
        activityTitle,
      );
      const activity = logicLabActivity(page);
      const iframe = logicLabIframe(activity);

      await expect(activity).toBeVisible();
      await expect(iframe).toBeVisible();
      await expect(iframe).toHaveAttribute('src', /mode=delivery/);
      await expect(iframe).toHaveAttribute('src', /activity=logic_lab_demo_activity/);
      await expect(iframe).toHaveAttribute('data-oli-attempt-guid', /.+/);
    });

    await test.step('logic lab save messages persist draft state and reload restores it', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.saveRestore,
        activityTitle,
      );
      let activity = logicLabActivity(page);
      const savedState = buildLogicLabState('draft_in_progress', 0, 1, false);

      await sendLogicLabSave(activity, savedState);

      await expect
        .poll(async () => requestLogicLabLoad(activity), {
          message: 'Expected logic lab load payload to return the saved draft state',
        })
        .toMatchObject({
          activity: 'logic_lab_demo_activity',
          save: JSON.stringify(savedState),
          state: savedState,
        });

      await page.reload({ waitUntil: 'load' });

      activity = logicLabActivity(page);

      await expect
        .poll(async () => requestLogicLabLoad(activity), {
          message: 'Expected logic lab draft state to restore after reload',
        })
        .toMatchObject({
          activity: 'logic_lab_demo_activity',
          save: JSON.stringify(savedState),
          state: savedState,
        });
    });
  });

  test('logic lab score messages persist complete and incomplete evaluated states', async ({
    homeTask,
    page,
  }) => {
    await homeTask.login('student');

    await test.step('logic lab complete score resets the attempt and restores the saved lab state', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.completeScore,
        activityTitle,
      );
      let activity = logicLabActivity(page);
      const completeState = buildLogicLabState('complete', 1, 1, true);

      await sendLogicLabScore(activity, {
        score: 1,
        outOf: 1,
        input: completeState,
        complete: true,
      });

      await expect
        .poll(async () => requestLogicLabLoad(activity), {
          message: 'Expected scored complete logic lab state to be available after reset',
        })
        .toMatchObject({
          activity: 'logic_lab_demo_activity',
          save: JSON.stringify(completeState),
          state: completeState,
        });

      await page.reload({ waitUntil: 'load' });

      activity = logicLabActivity(page);

      await expect
        .poll(async () => requestLogicLabLoad(activity), {
          message: 'Expected complete logic lab state to restore after reload',
        })
        .toMatchObject({
          activity: 'logic_lab_demo_activity',
          save: JSON.stringify(completeState),
          state: completeState,
        });
    });

    await test.step('logic lab incomplete score also restores the serialized lab state', async () => {
      await openStudentDeliveryPracticeForLoggedInStudent(
        page,
        sections.incompleteScore,
        activityTitle,
      );
      let activity = logicLabActivity(page);
      const incompleteState = buildLogicLabState('incomplete', 0, 1, false);

      await sendLogicLabScore(activity, {
        score: 0,
        outOf: 1,
        input: incompleteState,
        complete: false,
      });

      await expect
        .poll(async () => requestLogicLabLoad(activity), {
          message: 'Expected scored incomplete logic lab state to be available after reset',
        })
        .toMatchObject({
          activity: 'logic_lab_demo_activity',
          save: JSON.stringify(incompleteState),
          state: incompleteState,
        });

      await page.reload({ waitUntil: 'load' });

      activity = logicLabActivity(page);

      await expect
        .poll(async () => requestLogicLabLoad(activity), {
          message: 'Expected incomplete logic lab state to restore after reload',
        })
        .toMatchObject({
          activity: 'logic_lab_demo_activity',
          save: JSON.stringify(incompleteState),
          state: incompleteState,
        });
    });
  });
});

function logicLabActivity(page: Page) {
  return page.locator('oli-logic-lab-delivery').first();
}

function buildLogicLabState(
  status: string,
  score: number,
  outOf: number,
  objectiveComplete: boolean,
): LogicLabSaveState {
  return {
    problemId: `logic_lab_problem_${status}`,
    timestamp: new Date().toISOString(),
    data: {
      status,
      points: { score, outOf },
      best: { score, outOf },
      activityType: 'derivation',
      objectives: [
        {
          name: 'main_objective',
          complete: objectiveComplete,
          state: { status },
        },
      ],
    },
  };
}
