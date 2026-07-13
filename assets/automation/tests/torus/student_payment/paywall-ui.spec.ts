import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import path from 'node:path';
import { logInAsScenarioUser, seedScenarioUser, type SeededScenarioUser } from './support';

const runId = `-${Date.now()}`;
const scenarioPaths = {
  noGrace: path.resolve(__dirname, './unpaid-no-grace.scenario.yaml'),
  activeGrace: path.resolve(__dirname, './unpaid-active-grace.scenario.yaml'),
  expiredGrace: path.resolve(__dirname, './unpaid-expired-grace.scenario.yaml'),
  qualifyingDiscount: path.resolve(__dirname, './discount-qualifying.scenario.yaml'),
  nonQualifyingDiscount: path.resolve(__dirname, './discount-non-qualifying.scenario.yaml'),
  guest: path.resolve(__dirname, './guest-paid-section.scenario.yaml'),
} as const;

let noGraceScenario: SeededScenarioUser;
let activeGraceScenario: SeededScenarioUser;
let expiredGraceScenario: SeededScenarioUser;
let qualifyingDiscountScenario: SeededScenarioUser;
let nonQualifyingDiscountScenario: SeededScenarioUser;
let guestScenario: SeededScenarioUser;

test.beforeAll(async ({ seedScenario }) => {
  noGraceScenario = await seedScenarioUser(
    seedScenario,
    scenarioPaths.noGrace,
    runId,
    'student_payment_unpaid_no_grace_section',
    'student_payment_unpaid_no_grace_student',
  );

  activeGraceScenario = await seedScenarioUser(
    seedScenario,
    scenarioPaths.activeGrace,
    runId,
    'student_payment_unpaid_active_grace_section',
    'student_payment_unpaid_active_grace_student',
  );

  expiredGraceScenario = await seedScenarioUser(
    seedScenario,
    scenarioPaths.expiredGrace,
    runId,
    'student_payment_unpaid_expired_grace_section',
    'student_payment_unpaid_expired_grace_student',
  );

  qualifyingDiscountScenario = await seedScenarioUser(
    seedScenario,
    scenarioPaths.qualifyingDiscount,
    runId,
    'student_payment_discount_qualifying_section',
    'student_payment_discount_qualifying_student',
  );

  nonQualifyingDiscountScenario = await seedScenarioUser(
    seedScenario,
    scenarioPaths.nonQualifyingDiscount,
    runId,
    'student_payment_discount_non_qualifying_section',
    'student_payment_discount_non_qualifying_student',
  );

  guestScenario = await seedScenarioUser(
    seedScenario,
    scenarioPaths.guest,
    runId,
    'student_payment_guest_paid_section',
    'student_payment_guest_user',
  );
});

test.describe('student payment paywall UI', () => {
  test('unpaid learner without grace is blocked and sees the payment-required UI', async ({
    page,
  }) => {
    const sectionPath = sectionRootPath(noGraceScenario.sectionSlug);
    const paymentPath = sectionPaymentPath(noGraceScenario.sectionSlug);

    await logInAsScenarioUser(page, noGraceScenario.userEmail, sectionPath, paymentPath);

    await expect(page.getByRole('heading', { name: 'Payment Required' })).toBeVisible();
    await expect(page.getByText('There is a fee associated with this course:')).toBeVisible();
    await expect(page.getByText('$25.00')).toHaveCount(2);
    await expect(page.getByRole('link', { name: 'Pay by credit card' })).toBeVisible();
    await expect(page.getByText('Pay using a Payment Code')).toBeVisible();
  });

  test('unpaid learner within active grace can access the course and sees the pay-now banner', async ({
    page,
  }) => {
    const learnPath = sectionLearnPath(activeGraceScenario.sectionSlug);

    await logInAsScenarioUser(
      page,
      activeGraceScenario.userEmail,
      learnPath,
      `/sections/${activeGraceScenario.sectionSlug}/`,
    );

    const studentCourse = new StudentCoursePO(page);
    await studentCourse.goToCourseIfPrompted();

    await expect(page).not.toHaveURL(/\/payment$/);
    await expect(page.locator('#pay_early_message')).toBeVisible();
    await expect(page.locator('#pay_early_message')).toContainText(/grace period/i);
    await expect(page.getByRole('link', { name: 'Pay Now' })).toBeVisible();
    await expect(page.getByText('Paid Course Page').first()).toBeVisible();
  });

  test('unpaid learner with expired grace is blocked and sees the payment-required UI', async ({
    page,
  }) => {
    const sectionPath = sectionRootPath(expiredGraceScenario.sectionSlug);
    const paymentPath = sectionPaymentPath(expiredGraceScenario.sectionSlug);

    await logInAsScenarioUser(page, expiredGraceScenario.userEmail, sectionPath, paymentPath);

    await expect(page.getByRole('heading', { name: 'Payment Required' })).toBeVisible();
    await expect(page.locator('#pay_early_message')).toHaveCount(0);
    await expect(page.getByText('$25.00')).toHaveCount(2);
  });

  test('qualifying learner sees the discounted price', async ({ page }) => {
    const paymentPath = sectionPaymentPath(qualifyingDiscountScenario.sectionSlug);

    await logInAsScenarioUser(
      page,
      qualifyingDiscountScenario.userEmail,
      sectionRootPath(qualifyingDiscountScenario.sectionSlug),
      paymentPath,
    );

    await expect(page.getByRole('heading', { name: 'Payment Required' })).toBeVisible();
    await expect(page.getByText('$20.00')).toHaveCount(2);
    await expect(page.getByText('$25.00')).toHaveCount(0);
  });

  test('non-qualifying learner sees the standard price', async ({ page }) => {
    const paymentPath = sectionPaymentPath(nonQualifyingDiscountScenario.sectionSlug);

    await logInAsScenarioUser(
      page,
      nonQualifyingDiscountScenario.userEmail,
      sectionRootPath(nonQualifyingDiscountScenario.sectionSlug),
      paymentPath,
    );

    await expect(page.getByRole('heading', { name: 'Payment Required' })).toBeVisible();
    await expect(page.getByText('$25.00')).toHaveCount(2);
    await expect(page.getByText('$20.00')).toHaveCount(0);
  });

  test('guest learner sees account-required restrictions on paid section payment page', async ({
    page,
  }) => {
    const paymentPath = sectionPaymentPath(guestScenario.sectionSlug);

    await logInAsScenarioUser(page, guestScenario.userEmail, paymentPath);

    await expect(page).toHaveURL(new RegExp(`/sections/${guestScenario.sectionSlug}/payment`));
    await expect(page.getByRole('heading', { name: 'Payment and Account Required' })).toBeVisible();
    await expect(page.getByText('You are currently accessing the system as a guest')).toBeVisible();

    const accountLink = page.getByRole('link', { name: 'Sign in / Create an account' });
    await expect(accountLink).toBeVisible();
    await expect(accountLink).toHaveAttribute(
      'href',
      new RegExp(`/users/log_in\\?request_path=%2Fsections%2F${guestScenario.sectionSlug}%2Fenroll`),
    );

    await expect(page.getByText('Pay by credit card')).toHaveCount(0);
    await expect(page.getByText('Pay using a Payment Code')).toHaveCount(0);
  });
});

function sectionRootPath(sectionSlug: string) {
  return `/sections/${sectionSlug}`;
}

function sectionPaymentPath(sectionSlug: string) {
  return `/sections/${sectionSlug}/payment`;
}

function sectionLearnPath(sectionSlug: string) {
  return `/sections/${sectionSlug}/learn?sidebar_expanded=true&selected_view=outline`;
}
