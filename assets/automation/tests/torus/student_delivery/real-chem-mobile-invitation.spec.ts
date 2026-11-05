import { configureCaptcha } from '@core/captcha';
import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { devices, expect } from '@playwright/test';
import { CourseManagePO } from '@pom/course/CourseManagePO';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { LoginPO } from '@pom/home/LoginPO';
import { TYPE_USER } from '@pom/types/type-user';
import { fetchTestArchiveToTempFile } from '@tasks/AutomationAssetsTask';
import {
  AUTOMATION_SETUP_HOOK_TIMEOUT_MS,
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';
import fs from 'node:fs/promises';

/**
 * MER-6121: a signed-out student opens a Real Chem section invitation on a
 * phone, signs in, enrolls, and enters the course.
 *
 * The Real Chem II archive is imported without a learner; the student comes
 * from the companion scenario so it starts unenrolled. The instructor opens
 * registration, requires enrollment, and creates the invitation through the
 * section management UI.
 *
 * Requirements to run locally (see real-chem-greenhouse-molecules.spec.ts for
 * details): PLAYWRIGHT_AUTOMATION_API_KEY, PLAYWRIGHT_SCENARIO_TOKEN, and
 * real_chem_ii-mobile_invitation/course.zip in the playwright assets bucket.
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const archiveKey = 'real_chem_ii-mobile_invitation/course.zip';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const runId = `-${Date.now()}-${process.pid}`;
const studentPassword = 'changeme123456';
const sectionTitle = 'Automation test section';

let seededCourse: AutomationSetupResponse | null = null;
let archiveTempDir: string | null = null;

setRuntimeConfig({
  baseUrl,
  scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token',
});

test.skip(
  !automationApiKey,
  'Set PLAYWRIGHT_AUTOMATION_API_KEY to run this test (see setup instructions above)',
);

test.describe.serial('Real Chem mobile invitation', () => {
  test.beforeAll(async ({ request, seedScenario }) => {
    test.setTimeout(AUTOMATION_SETUP_HOOK_TIMEOUT_MS);

    const archive = await fetchTestArchiveToTempFile(archiveKey, baseUrl);
    archiveTempDir = archive.tempDir;

    const scenario = await seedScenario('./real-chem-mobile-invitation.scenario.yaml', {
      RUN_ID: runId,
    });
    const users = (scenario.outputs as { users?: Record<string, string> } | undefined)?.users;
    const studentEmail = users?.mobile_invitation_student ?? '';
    expect(studentEmail, 'Scenario did not return the student email').toBeTruthy();

    const setup = await importArchiveAndCreateSection(request, archive.filePath, {
      baseUrl,
      apiKey: automationApiKey!,
      learner: { email: studentEmail, password: studentPassword },
    });
    seededCourse = setup;

    const loginData = buildAutomationLoginData(studentEmail, studentPassword);
    setRuntimeConfig({
      loginData: {
        ...loginData,
        instructor: {
          ...loginData.instructor,
          type: TYPE_USER.instructor,
          email: setup.educator.email,
          pass: setup.educator.password,
        },
      },
    });
  });

  test.afterAll(async ({ request }) => {
    try {
      if (seededCourse) {
        await teardownAutomationCourse(request, seededCourse, {
          baseUrl,
          apiKey: automationApiKey!,
        });
      }
    } finally {
      resetRuntimeConfig();
      if (archiveTempDir) {
        await fs.rm(archiveTempDir, { recursive: true, force: true });
        archiveTempDir = null;
      }
    }
  });

  test('signed-out student enters the course from an invitation on a phone @nightly', async ({
    browser,
    page,
    homeTask,
  }) => {
    test.setTimeout(180_000);

    if (!seededCourse) {
      throw new Error('Automation setup did not produce seeded course data');
    }
    const sectionSlug = seededCourse.section.slug;

    // Instructor: open registration requiring enrollment and create the invitation link.
    await homeTask.login('instructor');
    const manage = new CourseManagePO(page);
    await manage.openRegistrationRequiringEnrollment(sectionSlug);
    await page.goto(`/sections/${sectionSlug}/invitations`);
    const inviteLink = await manage.createInviteLinkExpiringAfter('One day');

    const { defaultBrowserType: _, ...pixel5 } = devices['Pixel 5'];
    const studentContext = await browser.newContext({
      ...pixel5,
      baseURL: baseUrl,
      ignoreHTTPSErrors: true,
    });
    await configureCaptcha(studentContext, baseUrl);

    try {
      const studentPage = await studentContext.newPage();
      const login = new LoginPO(studentPage);
      const course = new StudentCoursePO(studentPage);

      // Student on a phone, signed out: the invitation sends them to sign in.
      await studentPage.goto(inviteLink);
      await expect(studentPage).toHaveURL(
        (url) =>
          url.pathname === '/users/log_in' &&
          url.searchParams.get('section') === sectionSlug &&
          url.searchParams.get('from_invitation_link?') === 'true',
      );

      await login.acceptCookies();
      await login.signIn(seededCourse.learner.email, seededCourse.learner.password);

      // After sign-in the student lands on the enrollment page of the right section.
      await expect(studentPage).toHaveURL(
        (url) => url.pathname === `/sections/${sectionSlug}/enroll`,
      );
      await expect(studentPage.getByRole('heading', { name: sectionTitle })).toBeVisible();
      const enrollButton = studentPage.getByRole('button', { name: 'Enroll', exact: true });
      await expect(enrollButton).toBeVisible();
      await course.enrollIfPrompted();

      // Enrolled: the student reaches the course home and opens the first lesson.
      await course.goToCourseIfPrompted();
      await expect(studentPage).toHaveURL((url) => url.pathname === `/sections/${sectionSlug}`);
      await course.openFirstAvailableLesson();
      await expect(studentPage).toHaveURL((url) =>
        url.pathname.startsWith(`/sections/${sectionSlug}/`),
      );
    } finally {
      await studentContext.close();
    }
  });
});
