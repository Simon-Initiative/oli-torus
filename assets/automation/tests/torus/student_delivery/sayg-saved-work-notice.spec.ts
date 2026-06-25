import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { MenuDropdownCO } from '@pom/home/MenuDropdownCO';
import path from 'node:path';
import { configureStudentDeliveryRuntimeConfig, seedStudentDeliveryScenario } from './support';

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './sayg-saved-work-notice.scenario.yaml');
const savedWorkStorageKey = 'torus.saygSavedWorkNotice';
const saygNoticeSourceSelector = '#sayg_navigation_notice_source';
const saygLessonTitle = 'San Lorenzo';
const saygLessonTitlePattern = new RegExp(saygLessonTitle, 'i');
const standardLessonTitle = 'Rosario Central';
const savedWorkMessage =
  'Your work has been saved. You can resume the assignment anytime before the due date.';

type UserMenuLink = 'Account Settings' | 'My Courses' | 'Research Consent';

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'sayg-notice-student',
    welcomeTitle: 'Hi, SAYG',
    name: 'SAYG',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'sayg-notice-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'sayg-notice-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'sayg-notice-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sectionSlug: string;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sectionSlug = outputs.sections?.sayg_saved_work_notice_section ?? '';
  expect(sectionSlug).toBeTruthy();
});

test.describe('SAYG saved work notice', () => {
  test.beforeEach(async ({ homeTask, page }) => {
    await homeTask.login('student');
    await page.evaluate((key) => sessionStorage.removeItem(key), savedWorkStorageKey);
    await gotoPath(page, learnPath());
    await enterCourseIfNeeded(page);
  });

  test('lesson back to home shows saved work notice', async ({ page }) => {
    await gotoPath(page, sectionHomePath());
    await expectHomePage(page);

    await openSaygLessonFromHome(page);
    await page.getByRole('link', { name: /Back/i }).first().click();

    await expectHomePage(page);
    await expectSavedWorkNotice(page);
  });

  test('lesson back to learn shows saved work notice', async ({ page }) => {
    await expectNoticeAfterLessonBack(page, learnPath(), expectLearnPage);
  });

  test('lesson back to schedule shows saved work notice', async ({ page }) => {
    await expectNoticeAfterLessonBack(page, schedulePath(), expectSchedulePage);
  });

  test('lesson back to assignments shows saved work notice', async ({ page }) => {
    await expectNoticeAfterLessonBack(page, assignmentsPath(), expectAssignmentsPage);
  });

  test('lesson bottom navigation shows saved work notice', async ({ page }) => {
    await gotoPath(page, learnPath());
    await expectLearnPage(page);
    await openSaygLessonFromCurrentPage(page);

    await revealBottomNavigation(page);
    const nextLessonLink = page.getByRole('link', { name: 'next' });
    await expect(nextLessonLink).toBeVisible();
    await nextLessonLink.click();

    await expectLessonTitle(page, standardLessonTitle);
    await expectSavedWorkNotice(page);
  });

  test('user menu to account settings shows saved work notice', async ({ page }) => {
    await openSaygLessonFromAssignments(page);
    await navigateFromUserMenu(page, 'Account Settings');

    await expect(page).toHaveURL(/\/users\/settings/);
    await expect(page.getByRole('heading', { name: 'Account Settings' })).toBeVisible();
    await expectSavedWorkNotice(page);
  });

  test('user menu to my courses shows saved work notice', async ({ page }) => {
    await openSaygLessonFromAssignments(page);
    await navigateFromUserMenu(page, 'My Courses');

    await expect(page).toHaveURL(/\/workspaces\/student/);
    await expect(page.getByText('Courses available').first()).toBeVisible();
    await expectSavedWorkNotice(page);
  });

  test('user menu to research consent shows saved work notice', async ({ page }) => {
    await openSaygLessonFromAssignments(page);
    await navigateFromUserMenu(page, 'Research Consent');

    await expect(page).toHaveURL(/\/research_consent/);
    await expect(page.getByText('Online Consent Form')).toBeVisible();
    await expectSavedWorkNotice(page);
  });
});

async function expectNoticeAfterLessonBack(
  page: Page,
  destinationPath: string,
  expectDestinationPage: (page: Page) => Promise<void>,
) {
  await gotoPath(page, destinationPath);
  await expectDestinationPage(page);

  await openSaygLessonFromCurrentPage(page);
  await page.getByRole('link', { name: /Back/i }).first().click();

  await expectDestinationPage(page);
  await expectSavedWorkNotice(page);
}

async function openSaygLessonFromHome(page: Page) {
  const resumeLessonLink = page
    .getByRole('link', { name: /Resume lesson/i })
    .or(page.getByRole('button', { name: /Resume lesson/i }))
    .first();

  if (await resumeLessonLink.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await resumeLessonLink.click();
    await waitForMainLiveView(page);
    await expectSaygLessonOpened(page);
    return;
  }

  const latestTab = page.locator('#latest_tab');

  await expect(latestTab).toBeVisible();

  if (await latestTab.isEnabled()) {
    await latestTab.click();
    await waitForMainLiveView(page);
  }

  await page.getByRole('link', { name: saygLessonTitlePattern }).first().click();
  await waitForMainLiveView(page);
  await expectSaygLessonOpened(page);
}

async function openSaygLessonFromCurrentPage(page: Page) {
  const sanLorenzoLink = page
    .getByRole('link', { name: saygLessonTitlePattern })
    .or(page.getByRole('button', { name: saygLessonTitlePattern }))
    .first();

  await expect(sanLorenzoLink).toBeVisible();
  await sanLorenzoLink.click();
  await waitForMainLiveView(page);
  await expectSaygLessonOpened(page);
}

async function openSaygLessonFromAssignments(page: Page) {
  await gotoPath(page, assignmentsPath());
  await expectAssignmentsPage(page);
  await openSaygLessonFromCurrentPage(page);
}

async function navigateFromUserMenu(page: Page, linkName: UserMenuLink) {
  const menu = new MenuDropdownCO(page);

  await menu.open();
  await clickVisibleUserMenuLink(page, linkName);
}

async function clickVisibleUserMenuLink(page: Page, name: UserMenuLink) {
  const menuLinks = page
    .locator('#workspace-user-menu-dropdown, #user-account-menu-dropdown')
    .getByRole('link', { name });
  const count = await menuLinks.count();

  for (let i = 0; i < count; i++) {
    const link = menuLinks.nth(i);

    if (await link.isVisible().catch(() => false)) {
      await link.click();
      return;
    }
  }

  throw new Error(`User menu link '${name}' was not visible`);
}

async function revealBottomNavigation(page: Page) {
  const bottomBarWrapper = page.locator('#bottom-bar-wrapper');

  await expect(bottomBarWrapper).toBeAttached();
  await bottomBarWrapper.hover();
}

async function waitForMainLiveView(page: Page) {
  await page.waitForFunction(
    () => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'),
    undefined,
    { timeout: 15_000 },
  );
}

async function enterCourseIfNeeded(page: Page) {
  const goToCourseButton = page.getByRole('button', { name: 'Go to course' });

  if (await goToCourseButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await goToCourseButton.click();
    await expect(goToCourseButton).toBeHidden({ timeout: 10_000 });
  }
}

async function expectSavedWorkNotice(page: Page) {
  const notice = page.locator('#sayg_saved_work_notice');

  await expect(notice).toBeVisible();
  await expect(notice).toContainText(savedWorkMessage);
}

async function expectSaygLessonOpened(page: Page) {
  await expectLessonTitle(page, saygLessonTitle);
  await expect(page.locator(saygNoticeSourceSelector)).toBeAttached();
}

async function expectLessonTitle(page: Page, title: string) {
  await expect(page.getByText(title).first()).toBeVisible();
}

async function expectAssignmentsPage(page: Page) {
  await expect(page.getByRole('heading', { name: 'Assignments' })).toBeVisible();
}

async function expectSchedulePage(page: Page) {
  await expect(page.getByRole('heading', { name: 'Course Schedule' })).toBeVisible();
}

async function expectHomePage(page: Page) {
  await expect(page.locator('#home-assignments')).toBeVisible();
}

async function expectLearnPage(page: Page) {
  await expect(page.locator('#student_learn')).toBeVisible();
}

function sectionHomePath() {
  return `/sections/${sectionSlug}?sidebar_expanded=true`;
}

function assignmentsPath() {
  return `/sections/${sectionSlug}/assignments?sidebar_expanded=true`;
}

function schedulePath() {
  return `/sections/${sectionSlug}/student_schedule?sidebar_expanded=true`;
}

function learnPath() {
  const searchTerm = encodeURIComponent(saygLessonTitle);

  return `/sections/${sectionSlug}/learn?sidebar_expanded=true&selected_view=outline&search_term=${searchTerm}`;
}

async function gotoPath(page: Page, path: string) {
  await page.goto(path, { waitUntil: 'load' });
}
