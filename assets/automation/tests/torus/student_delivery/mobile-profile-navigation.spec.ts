import { extractAccountLink, waitForMailboxEmail } from '@core/mailbox';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { devices, expect, type Page } from '@playwright/test';
import { StudentCourseViewsPO } from '@pom/course/StudentCourseViewsPO';
import { MobileCourseNavCO } from '@pom/delivery/MobileCourseNavCO';
import { StudentLessonPO } from '@pom/delivery/StudentLessonPO';
import { AccountSettingsPO } from '@pom/home/AccountSettingsPO';
import { CookiePreferencesPO } from '@pom/home/CookiePreferencesPO';
import { LoginPO } from '@pom/home/LoginPO';
import { MobileUserMenuCO } from '@pom/home/MobileUserMenuCO';
import { ResearchConsentPO } from '@pom/home/ResearchConsentPO';
import { baseUrl, defaultPassword, scenarioToken, seedStudentDeliveryScenario } from './support';

/**
 * MER-6122: on a phone (Pixel 5), an enrolled student updates profile settings, opens the
 * course views, and moves between lessons with the lower Previous/Next controls.
 *
 * Settings covered, each saved through the UI and checked again after a reload, a later visit,
 * or a new sign-in:
 * - Account Settings: name, email (confirmed through the emailed link), and password.
 * - User menu: theme, Show Math Previews, timezone, research consent, and cookie preferences.
 *
 * Course views covered: Home, Learn, Explorations, and Notes. Each shows its own content and
 * leads back to a lesson.
 *
 * Known issues worked around (not fixed here):
 * - A LiveView patch hides the lesson Previous/Next bar again right after it connects, and only
 *   scrolling brings it back, so the scenario pages are taller than the screen.
 * - The mobile user menu is taller than the screen, so its top rows (Back, Account Settings,
 *   My Courses) are out of reach; the spec uses the course menu's Settings link instead.
 */
const { defaultBrowserType: _, ...pixel5 } = devices['Pixel 5'];
test.use({ ...pixel5 });

const runId = `-${Date.now()}`;
const scenarioPath = './mobile-profile-navigation.scenario.yaml';
const studentEmail = `mobile-profile-navigation-student${runId}@example.com`;
const credentialsStudentEmail = `mobile-profile-credentials-student${runId}@example.com`;
const firstPage = 'Mobile First Page';
const middlePage = 'Mobile Middle Page';
const lastPage = 'Mobile Exploration Page';
const sectionTitle = `Mobile Profile Navigation Section ${runId}`;

setRuntimeConfig({ baseUrl, scenarioToken });

let sectionSlug: string;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sectionSlug = outputs.sections?.mobile_profile_navigation_section ?? '';
  expect(sectionSlug, 'Scenario did not return the section slug').toBeTruthy();
});

test.describe('Mobile profile settings and course navigation', () => {
  test('profile preferences persist after saving @nightly', async ({ page }) => {
    const nav = new MobileCourseNavCO(page);
    const userMenu = new MobileUserMenuCO(page);
    const settings = new AccountSettingsPO(page);
    const researchConsent = new ResearchConsentPO(page);
    const cookies = new CookiePreferencesPO(page);
    const views = new StudentCourseViewsPO(page);

    await signInAndEnterCourse(page, studentEmail, defaultPassword);

    // Name, on Account Settings.
    await nav.goToAccountSettings();
    await settings.expectLoaded();
    await settings.updateName('Phone', 'Learner');
    await settings.reload();
    await settings.expectName('Phone', 'Learner');
    await settings.goBack();
    await expect(page).toHaveURL((url) => url.pathname === `/sections/${sectionSlug}`);
    await nav.expectUserName('Phone Learner');

    // Theme, in the user menu.
    await nav.openUserMenu();
    await userMenu.selectTheme('dark');
    await userMenu.expectDarkThemeApplied();
    // Dismissing the menus leaves the course usable without a reload.
    await nav.close();
    await userMenu.expectClosed();
    await nav.goTo('Learn');
    await views.expectLearn([firstPage, middlePage, lastPage]);
    await userMenu.expectDarkThemeApplied();
    await page.reload();
    await userMenu.expectDarkThemeApplied();
    await nav.openUserMenu();
    await userMenu.expectTheme('dark');

    // Show Math Previews: saving redirects back to the course page.
    await userMenu.setShowMathPreviews(false);
    await expect(page.getByText('Preference updated successfully.')).toBeVisible();
    await page.reload();
    await nav.openUserMenu();
    await userMenu.expectShowMathPreviews(false);

    // Timezone: saving also redirects back to the course page.
    const timezone = await userMenu.selectNextTimezone();
    await expect(page.getByText('Timezone updated successfully.')).toBeVisible();
    await page.reload();
    await nav.openUserMenu();
    await userMenu.expectTimezone(timezone);

    // Research consent: the form sends the student to their courses after saving.
    await userMenu.goToResearchConsent();
    await researchConsent.expectLoaded();
    await researchConsent.expectConsent(true);
    await researchConsent.submit(false);
    await enterCourse(page);
    await nav.openUserMenu();
    await userMenu.goToResearchConsent();
    await researchConsent.expectConsent(false);

    // Cookie preferences.
    await enterCourse(page);
    await nav.openUserMenu();
    await userMenu.goToCookiePreferences();
    await cookies.expectLoaded();
    await cookies.setCategory('Targeting Cookies', true);
    await cookies.save();
    await page.reload();
    await cookies.expectLoaded();
    await cookies.expectCategory('Targeting Cookies', true);
  });

  test('email and password changes persist @nightly', async ({ page, request }) => {
    const nav = new MobileCourseNavCO(page);
    const userMenu = new MobileUserMenuCO(page);
    const settings = new AccountSettingsPO(page);
    const newEmail = `mobile-profile-credentials-updated${runId}@example.com`;
    const newPassword = 'changedpassword123456';

    await signInAndEnterCourse(page, credentialsStudentEmail, defaultPassword);
    await nav.goToAccountSettings();
    await settings.expectLoaded();

    // Email: the change only applies once the link sent to the new address is opened.
    await settings.requestEmailChange(newEmail, defaultPassword);
    await settings.reload();
    await settings.expectEmail(credentialsStudentEmail);
    const confirmation = await waitForMailboxEmail(request, {
      baseUrl,
      recipient: newEmail,
      subject: 'Confirm your email',
      token: scenarioToken,
    });
    await settings.confirmEmailChange(
      extractAccountLink(
        confirmation.html_body,
        confirmation.text_body,
        'users',
        'settings/confirm_email',
      ),
    );
    await settings.expectEmail(newEmail);

    // Password, in its own save: saving it together with an email change currently fails.
    await settings.changePassword(defaultPassword, newPassword);

    // Both persist: the old password is rejected, and the new email and password sign back in.
    await enterCourse(page);
    await nav.openUserMenu();
    await userMenu.signOut();
    await signIn(page, newEmail, defaultPassword);
    await expect(page.getByText('Invalid email or password')).toBeVisible();
    await expect(page).toHaveURL((url) => url.pathname === '/users/log_in');
    await signInAndEnterCourse(page, newEmail, newPassword);
  });

  test('course views open and return to a lesson @nightly', async ({ page }) => {
    const nav = new MobileCourseNavCO(page);
    const views = new StudentCourseViewsPO(page);
    const lesson = new StudentLessonPO(page);
    const noteText = `Mobile note ${runId}`;

    await signInAndEnterCourse(page, studentEmail, defaultPassword);

    await nav.goTo('Learn');
    await views.expectLearn([firstPage, middlePage, lastPage]);
    await views.openFromLearn(firstPage);
    await lesson.addPageNote(noteText);
    await lesson.closeNotes();
    await lesson.goBack();
    await views.expectLearn([firstPage, middlePage, lastPage]);

    await nav.goTo('Explorations');
    await views.expectExplorations(lastPage);
    await views.openExploration(lastPage);
    await lesson.goBack();
    await views.expectExplorations(lastPage);

    await nav.goTo('Notes');
    await views.expectNotes(noteText);
    await views.openNotePage(noteText, firstPage);
    await lesson.goBack();

    // A dismissed menu leaves the page usable.
    await nav.open();
    await nav.close();
    await nav.goTo('Home');
    await views.expectHome(sectionTitle);
    await views.continueFromHome();
  });

  test('lower Previous and Next controls move between lessons @nightly', async ({ page }) => {
    const nav = new MobileCourseNavCO(page);
    const views = new StudentCourseViewsPO(page);
    const lesson = new StudentLessonPO(page);

    await signInAndEnterCourse(page, studentEmail, defaultPassword);

    await nav.goTo('Learn');
    await views.openFromLearn(middlePage);
    await lesson.expectBottomControls(true, true);

    await lesson.goNext();
    await lesson.expectLoaded(lastPage);
    await lesson.expectBottomControls(true, false);

    await lesson.goPrevious();
    await lesson.expectLoaded(middlePage);

    await lesson.goPrevious();
    await lesson.expectLoaded(firstPage);
    await lesson.expectBottomControls(false, true);

    await lesson.goNext();
    await lesson.expectLoaded(middlePage);
  });
});

async function signIn(page: Page, email: string, password: string) {
  const login = new LoginPO(page);

  await page.goto('/users/log_in');
  await login.acceptCookies();
  await login.signIn(email, password);
}

async function signInAndEnterCourse(page: Page, email: string, password: string) {
  await signIn(page, email, password);
  await expect(page).toHaveURL((url) => url.pathname === '/workspaces/student');
  await enterCourse(page);
}

async function enterCourse(page: Page) {
  await page.goto(`/sections/${sectionSlug}`);
  await new StudentCourseViewsPO(page).expectHome(sectionTitle);
}
