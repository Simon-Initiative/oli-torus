/**
 * Provisions a disposable Moodle course via the API, imports a pre-configured LTI activity
 * into it from a persistent template course, launches that activity from Moodle into Torus,
 * and drives the Torus wizard to create a section from it — then tears both down. See
 * moodle_playwright.md for the external fixtures this test assumes.
 */
import { expect, test } from '@playwright/test';
import {
  acceptCookiesIfVisible,
  createTorusSectionFromLaunch,
  deleteTorusSectionFromManage,
  type RoleScope,
} from '../lti/support/torusLtiFixture';
import {
  createMoodleContext,
  followMoodleToolLaunch,
  getMoodleBaseUrl,
  getMoodleInstructorCredentials,
  getMoodleLtiToolName,
  launchTokamakFromMoodle,
  loginToMoodle,
} from './support/moodle';
import {
  createMoodleCourse,
  deleteMoodleCourse,
  deleteMoodleCourseByShortnameIfExists,
  enrolMoodleTeacher,
  getMoodleCourseByShortname,
  getMoodleUserIdByUsername,
  importMoodleCourseContent,
  type MoodleCourse,
} from '../../../src/systems/moodle/api/MoodleApi';
import { requireEnv } from '../../support/testConfig';

// Fixed Moodle course identifiers. The course is created fresh at the start of each run and
// deleted at the end. A fixed name (rather than a per-run timestamped one) lets each run search
// for and delete a leftover from a previous run that crashed before its own cleanup ran, instead
// of accumulating orphaned courses.
const MOODLE_COURSE_SHORTNAME = 'playwright_moodle_lti_launch_test';
const MOODLE_COURSE_FULLNAME = 'Playwright Moodle LTI Launch Test';

// Persistent, manually-provisioned template course (see moodle_playwright.md) containing a
// single LTI activity backed by the pre-registered tool named MOODLE_LTI_TOOL_NAME. Moodle's web
// service API has no function to create a fully-configured mod_lti activity instance directly,
// so each run imports this course's content into the fresh course above instead
// (core_course_import_course) rather than adding the activity through the UI.
const MOODLE_TEMPLATE_COURSE_SHORTNAME = 'playwright_moodle_lti_template';

// This Torus project is a persistent, manually-provisioned fixture (see moodle_playwright.md),
// shared with moodle-grade-passback.spec.ts — this spec does not create, search for, or delete
// it. Each run still creates a brand-new Moodle course, i.e. a fresh LTI launch context, so the
// "New course set up" wizard is guaranteed to appear regardless of any section left over in this
// project from a previous run (see the cleanup note in the `finally` block below).
const TORUS_PROJECT_TITLE = 'PLAYWRIGHT_MOODLE_LTI_TEST';

// Every Moodle site has this default top-level category (id 1) out of the box. Using it keeps
// this disposable automation course out of any real, curated category structure.
const MOODLE_CATEGORY_ID = '1';

test('test simple LTI launch from Moodle @nightly', async ({ browser }) => {
  test.setTimeout(300_000);

  const moodleBaseUrl = getMoodleBaseUrl();
  const { email: moodleEmail, password: moodlePassword } = getMoodleInstructorCredentials();
  const moodleApiToken = requireEnv('MOODLE_API_TOKEN');
  const moodleToolName = getMoodleLtiToolName();
  const runId = `lti-moodle-${Date.now()}`;
  const sectionTitle = TORUS_PROJECT_TITLE;
  let moodleCourse: MoodleCourse | null = null;
  let sectionScope: RoleScope | null = null;
  const moodleContext = await createMoodleContext(browser);
  const page = await moodleContext.newPage();

  try {
    // Self-healing cleanup: remove a Moodle course left over from a previous run that crashed
    // before reaching its own cleanup, instead of accumulating orphaned courses.
    await deleteMoodleCourseByShortnameIfExists({
      baseUrl: moodleBaseUrl,
      token: moodleApiToken,
      shortname: MOODLE_COURSE_SHORTNAME,
    });

    moodleCourse = await createMoodleCourse({
      baseUrl: moodleBaseUrl,
      token: moodleApiToken,
      fullname: MOODLE_COURSE_FULLNAME,
      shortname: MOODLE_COURSE_SHORTNAME,
      categoryId: MOODLE_CATEGORY_ID,
    });

    // Creating a course does not enrol anyone in it — the instructor needs a Teacher
    // enrolment before they can access the course at all, let alone the activity within it.
    const instructorUserId = await getMoodleUserIdByUsername({
      baseUrl: moodleBaseUrl,
      token: moodleApiToken,
      username: moodleEmail,
    });
    await enrolMoodleTeacher({
      baseUrl: moodleBaseUrl,
      token: moodleApiToken,
      courseId: moodleCourse.id,
      userId: instructorUserId,
    });

    const templateCourse = await getMoodleCourseByShortname({
      baseUrl: moodleBaseUrl,
      token: moodleApiToken,
      shortname: MOODLE_TEMPLATE_COURSE_SHORTNAME,
    });

    if (templateCourse == null) {
      throw new Error(
        `Moodle template course with shortname "${MOODLE_TEMPLATE_COURSE_SHORTNAME}" was not ` +
          'found. This fixture course must be provisioned manually — see moodle_playwright.md.',
      );
    }

    await importMoodleCourseContent({
      baseUrl: moodleBaseUrl,
      token: moodleApiToken,
      importFromCourseId: templateCourse.id,
      importToCourseId: moodleCourse.id,
    });

    await loginToMoodle(page, moodleBaseUrl, moodleEmail, moodlePassword);
    const popup = await launchTokamakFromMoodle(page, moodleBaseUrl, moodleCourse.id, moodleToolName);

    const { toolPage, toolFrame } = await followMoodleToolLaunch(page, popup);
    const scope = toolPage ?? toolFrame!;
    sectionScope = scope;

    await acceptCookiesIfVisible(scope);
    await createTorusSectionFromLaunch(scope, {
      sourceTitle: TORUS_PROJECT_TITLE,
      sectionTitle,
      sectionNumber: runId,
    });

    if (toolPage != null) {
      await expect(toolPage).toHaveURL(/\/sections\/[^/]+\/manage$/, { timeout: 60_000 });
      await expect(toolPage.getByRole('link', { name: 'Overview' })).toBeVisible();
      await expect(toolPage.getByText(sectionTitle, { exact: true }).first()).toBeVisible();
    } else {
      await expect(toolFrame!.getByRole('link', { name: 'Overview' })).toBeVisible({
        timeout: 60_000,
      });
      await expect(toolFrame!.getByText(sectionTitle, { exact: true }).first()).toBeVisible();
    }
  } finally {
    // Best-effort: delete the section created above, if the launch got that far. Wrapped in its
    // own try/catch so a failure here (e.g. the launch never reached section creation) cannot
    // prevent the Moodle course cleanup below from running.
    if (sectionScope != null) {
      try {
        await deleteTorusSectionFromManage(sectionScope);
      } catch (error) {
        console.warn('Failed to delete the Torus section during cleanup:', error);
      }
    }

    if (moodleCourse != null) {
      try {
        await deleteMoodleCourse({
          baseUrl: moodleBaseUrl,
          token: moodleApiToken,
          courseId: moodleCourse.id,
        });
      } catch (error) {
        console.warn('Failed to delete the Moodle course during cleanup:', error);
      }
    }

    await moodleContext.close();
  }
});
