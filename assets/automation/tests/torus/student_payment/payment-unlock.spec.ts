import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import path from 'node:path';
import {
  logInAsScenarioUser,
  postInBrowser,
  postJsonInBrowser,
  seedStudentPaymentScenario,
  type SeededScenarioUser,
  submitPaymentCode,
} from './support';

const runId = `-${Date.now()}`;
const scenarioPaths = {
  paymentCode: path.resolve(__dirname, './payment-code-unlock.scenario.yaml'),
  stripe: path.resolve(__dirname, './stripe-unlock.scenario.yaml'),
  cashnet: path.resolve(__dirname, './cashnet-unlock.scenario.yaml'),
} as const;

type UnlockScenario = SeededScenarioUser & {
  extra: string;
  extra2?: string;
};

let paymentCodeScenario: UnlockScenario;
let stripeScenario: UnlockScenario;
let cashnetScenario: UnlockScenario;

test.beforeAll(async ({ seedScenario }) => {
  const paymentCodeOutputs = await seedStudentPaymentScenario(seedScenario, scenarioPaths.paymentCode, runId);
  paymentCodeScenario = {
    sectionSlug: paymentCodeOutputs.sections?.student_payment_code_unlock_section ?? '',
    userEmail: paymentCodeOutputs.users?.student_payment_code_unlock_student ?? '',
    extra: paymentCodeOutputs.params?.payment_code ?? '',
  };

  const stripeOutputs = await seedStudentPaymentScenario(seedScenario, scenarioPaths.stripe, runId);
  stripeScenario = {
    sectionSlug: stripeOutputs.sections?.student_payment_stripe_unlock_section ?? '',
    userEmail: stripeOutputs.users?.student_payment_stripe_unlock_student ?? '',
    extra: stripeOutputs.params?.stripe_intent_id ?? '',
  };

  const cashnetOutputs = await seedStudentPaymentScenario(seedScenario, scenarioPaths.cashnet, runId);
  cashnetScenario = {
    sectionSlug: cashnetOutputs.sections?.student_payment_cashnet_unlock_section ?? '',
    userEmail: cashnetOutputs.users?.student_payment_cashnet_unlock_student ?? '',
    extra: cashnetOutputs.params?.cashnet_payment_ref ?? '',
    extra2: cashnetOutputs.params?.cashnet_lname ?? '',
  };

  expect(paymentCodeScenario.sectionSlug).toBeTruthy();
  expect(paymentCodeScenario.userEmail).toBeTruthy();
  expect(paymentCodeScenario.extra).toBeTruthy();

  expect(stripeScenario.sectionSlug).toBeTruthy();
  expect(stripeScenario.userEmail).toBeTruthy();
  expect(stripeScenario.extra).toBeTruthy();

  expect(cashnetScenario.sectionSlug).toBeTruthy();
  expect(cashnetScenario.userEmail).toBeTruthy();
  expect(cashnetScenario.extra).toBeTruthy();
  expect(cashnetScenario.extra2).toBeTruthy();
});

test.describe('student payment unlock', () => {
  test('learner unlocks a paid section with a payment code', async ({ page }) => {
    await openBlockedSection(page, paymentCodeScenario);

    await page.goto(sectionPaymentCodePath(paymentCodeScenario.sectionSlug), { waitUntil: 'load' });
    await expect(page.getByRole('heading', { name: 'Enter Payment Code' })).toBeVisible();

    await submitPaymentCode(page, paymentCodeScenario.extra);

    await expect(page.getByRole('heading', { name: 'Payment Code Applied' })).toBeVisible();
    await page.getByRole('link', { name: 'Go to my course' }).click();

    await expectUnlockedCourse(page, paymentCodeScenario.sectionSlug);
  });

  test('invalid payment code keeps the learner blocked', async ({ page }) => {
    await openBlockedSection(page, paymentCodeScenario);

    await page.goto(sectionPaymentCodePath(paymentCodeScenario.sectionSlug), { waitUntil: 'load' });
    await expect(page.getByRole('heading', { name: 'Enter Payment Code' })).toBeVisible();

    await submitPaymentCode(page, 'BAD-CODE');

    await expect(page.getByRole('heading', { name: 'Enter Payment Code' })).toBeVisible();
    await expect(page.getByText('This is an invalid code')).toBeVisible();

    await page.goto(sectionRootPath(paymentCodeScenario.sectionSlug), { waitUntil: 'load' });
    await expectBlockedCourse(page, paymentCodeScenario.sectionSlug);
  });

  test('learner unlocks a paid section after simulated Stripe success', async ({ page }) => {
    await openBlockedSection(page, stripeScenario);

    const result = await postJsonInBrowser<{ result: string; url?: string }>(page, '/api/v1/payments/s/success', {
      intent: { id: stripeScenario.extra, status: 'succeeded' },
    });

    expect(result.status).toBe(200);
    expect(result.body.result).toBe('success');

    await page.goto(result.body.url ?? sectionRootPath(stripeScenario.sectionSlug), { waitUntil: 'load' });
    await expectUnlockedCourse(page, stripeScenario.sectionSlug);
  });

  test('unknown Stripe intent does not unlock the paid section', async ({ page }) => {
    await openBlockedSection(page, stripeScenario);

    const result = await postJsonInBrowser<{ result: string; reason?: string }>(page, '/api/v1/payments/s/success', {
      intent: { id: 'pi_missing_unlock', status: 'succeeded' },
    });

    expect(result.status).toBe(200);
    expect(result.body.result).toBe('failure');

    await page.goto(sectionRootPath(stripeScenario.sectionSlug), { waitUntil: 'load' });
    await expectBlockedCourse(page, stripeScenario.sectionSlug);
  });

  test('learner unlocks a paid section after simulated Cashnet success', async ({ page }) => {
    await openBlockedSection(page, cashnetScenario);

    const result = await postJsonInBrowser<{ result: string }>(page, '/api/v1/payments/c/success', {
      result: '0',
      respmessage: 'SUCCESS',
      lname: cashnetScenario.extra2 ?? 'none',
      ref1val1: cashnetScenario.extra,
    });

    expect(result.status).toBe(200);
    expect(result.body.result).toBe('success');

    await page.goto(sectionRootPath(cashnetScenario.sectionSlug), { waitUntil: 'load' });
    await expectUnlockedCourse(page, cashnetScenario.sectionSlug);
  });

  test('invalid Cashnet payload does not unlock the paid section', async ({ page }) => {
    await openBlockedSection(page, cashnetScenario);

    const result = await postInBrowser(page, '/api/v1/payments/c/success', {
      result: '1',
      respmessage: 'FAILURE',
      lname: 'bad-source',
      ref1val1: cashnetScenario.extra,
    });

    expect(result.status).toBe(401);
    expect(result.text).toContain('unauthorized');

    await page.goto(sectionRootPath(cashnetScenario.sectionSlug), { waitUntil: 'load' });
    await expectBlockedCourse(page, cashnetScenario.sectionSlug);
  });
});

async function openBlockedSection(page: Page, scenario: SeededScenarioUser) {
  await logInAsScenarioUser(
    page,
    scenario.userEmail,
    sectionRootPath(scenario.sectionSlug),
    sectionPaymentPath(scenario.sectionSlug),
  );

  await expect(page.getByRole('heading', { name: 'Payment Required' })).toBeVisible();
}

async function expectUnlockedCourse(page: Page, sectionSlug: string) {
  const studentCourse = new StudentCoursePO(page);

  await page.goto(sectionLearnPath(sectionSlug), { waitUntil: 'load' });
  await studentCourse.goToCourseIfPrompted();
  await studentCourse.presentAssignmentBlock();
  await expect(page).not.toHaveURL(/\/payment(\/code)?$/);
  await expect(page).toHaveURL(new RegExp(`/sections/${sectionSlug}`));
}

async function expectBlockedCourse(page: Page, sectionSlug: string) {
  await expect(page).toHaveURL(new RegExp(`/sections/${sectionSlug}/payment`));
  await expect(page.getByRole('heading', { name: 'Payment Required' })).toBeVisible();
}

function sectionRootPath(sectionSlug: string) {
  return `/sections/${sectionSlug}`;
}

function sectionPaymentPath(sectionSlug: string) {
  return `/sections/${sectionSlug}/payment`;
}

function sectionPaymentCodePath(sectionSlug: string) {
  return `/sections/${sectionSlug}/payment/code`;
}

function sectionLearnPath(sectionSlug: string) {
  return `/sections/${sectionSlug}/learn?sidebar_expanded=true&selected_view=outline`;
}
