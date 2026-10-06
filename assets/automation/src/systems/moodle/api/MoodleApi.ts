/**
 * Thin client for Moodle's REST web service API, used by the Moodle LTI Playwright specs to
 * provision/tear down the disposable fixture course and enrol/import content into it.
 */
export type MoodleCourse = {
  id: number;
  fullname: string;
  shortname: string;
  categoryid: number;
};

type MoodleApiParams = {
  baseUrl: string;
  token: string;
};

export type CreateMoodleCourseParams = MoodleApiParams & {
  fullname: string;
  shortname: string;
  categoryId: string;
};

export type DeleteMoodleCourseParams = MoodleApiParams & {
  courseId: number;
};

export type GetMoodleCourseByShortnameParams = MoodleApiParams & {
  shortname: string;
};

export type GetMoodleUserIdByUsernameParams = MoodleApiParams & {
  username: string;
};

export type EnrolMoodleTeacherParams = MoodleApiParams & {
  courseId: number;
  userId: number;
};

export type ImportMoodleCourseContentParams = MoodleApiParams & {
  importFromCourseId: number;
  importToCourseId: number;
};

// Standard Moodle installations seed this fixed set of default roles, in this order, on first
// install (Manager=1, Course creator=2, Teacher/editingteacher=3, ...). There is no web service
// function that looks up a role id by shortname, so this is a well-known constant rather than a
// value read from the API; an incorrect id fails loudly (invalid roleid) rather than silently.
const EDITING_TEACHER_ROLE_ID = 3;

// Looks up a course by its (site-unique) shortname, returning null when none exists.
export async function getMoodleCourseByShortname({
  baseUrl,
  token,
  shortname,
}: GetMoodleCourseByShortnameParams): Promise<MoodleCourse | null> {
  const result = await moodleApiRequest<{ courses: MoodleCourse[] }>(
    baseUrl,
    token,
    'core_course_get_courses_by_field',
    { field: 'shortname', value: shortname },
  );

  return result.courses[0] ?? null;
}

export async function createMoodleCourse({
  baseUrl,
  token,
  fullname,
  shortname,
  categoryId,
}: CreateMoodleCourseParams): Promise<MoodleCourse> {
  const result = await moodleApiRequest<MoodleCourse[]>(
    baseUrl,
    token,
    'core_course_create_courses',
    {
      courses: [
        {
          fullname,
          shortname,
          categoryid: categoryId,
        },
      ],
    },
  );

  if (result.length === 0) {
    throw new Error(`core_course_create_courses returned no course for shortname "${shortname}"`);
  }

  return result[0];
}

export async function deleteMoodleCourse({ baseUrl, token, courseId }: DeleteMoodleCourseParams) {
  await moodleApiRequest<unknown>(baseUrl, token, 'core_course_delete_courses', {
    courseids: [courseId],
  });
}

// Resolves a Moodle username to its numeric user id, required by enrol_manual_enrol_users.
export async function getMoodleUserIdByUsername({
  baseUrl,
  token,
  username,
}: GetMoodleUserIdByUsernameParams): Promise<number> {
  const result = await moodleApiRequest<Array<{ id: number }>>(
    baseUrl,
    token,
    'core_user_get_users_by_field',
    { field: 'username', values: [username] },
  );

  if (result.length === 0) {
    throw new Error(`No Moodle user found with username "${username}"`);
  }

  return result[0].id;
}

// Enrols a user as Teacher (editingteacher) in a course. Creating a course does not enrol
// anyone in it, so this must run before that user can access the course at all.
export async function enrolMoodleTeacher({
  baseUrl,
  token,
  courseId,
  userId,
}: EnrolMoodleTeacherParams) {
  await moodleApiRequest<unknown>(baseUrl, token, 'enrol_manual_enrol_users', {
    enrolments: [
      {
        roleid: EDITING_TEACHER_ROLE_ID,
        userid: userId,
        courseid: courseId,
      },
    ],
  });
}

// Imports course content (activities, blocks, filters — no user data, per Moodle's own docs)
// from one course into another already-created course. This is how the LTI activity gets into
// the fixture course: Moodle's web service API has no function that creates a fully-configured
// mod_lti instance directly (see moodle_playwright.md), so instead the activity is imported from
// a persistent, manually-provisioned template course.
export async function importMoodleCourseContent({
  baseUrl,
  token,
  importFromCourseId,
  importToCourseId,
}: ImportMoodleCourseContentParams) {
  await moodleApiRequest<unknown>(baseUrl, token, 'core_course_import_course', {
    importfrom: importFromCourseId,
    importto: importToCourseId,
    deletecontent: 0,
  });
}

// Self-healing cleanup for the fixed-shortname course used by moodle-launch.spec.ts: deletes a
// course left over from a previous run that crashed before its own cleanup ran, if one exists.
export async function deleteMoodleCourseByShortnameIfExists({
  baseUrl,
  token,
  shortname,
}: GetMoodleCourseByShortnameParams) {
  const existing = await getMoodleCourseByShortname({ baseUrl, token, shortname });

  if (existing != null) {
    await deleteMoodleCourse({ baseUrl, token, courseId: existing.id });
  }
}

async function moodleApiRequest<T>(
  baseUrl: string,
  token: string,
  wsfunction: string,
  params: Record<string, unknown> = {},
): Promise<T> {
  const url = new URL('/webservice/rest/server.php', baseUrl);
  const body = new URLSearchParams();
  body.set('wstoken', token);
  body.set('wsfunction', wsfunction);
  body.set('moodlewsrestformat', 'json');
  appendMoodleParams(body, params);

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  if (!response.ok) {
    throw new Error(`${wsfunction} failed (${response.status}): ${await response.text()}`);
  }

  const json = (await response.json()) as unknown;

  if (json != null && typeof json === 'object' && 'exception' in json) {
    const error = json as { message?: string; errorcode?: string };
    throw new Error(
      `${wsfunction} failed: ${error.message ?? error.errorcode ?? JSON.stringify(json)}`,
    );
  }

  return json as T;
}

// Encodes nested arrays/objects using the bracketed key notation Moodle's REST protocol expects,
// e.g. { courses: [{ fullname: 'x' }] } becomes courses[0][fullname]=x.
function appendMoodleParams(body: URLSearchParams, value: unknown, prefix = '') {
  if (Array.isArray(value)) {
    value.forEach((item, index) => appendMoodleParams(body, item, `${prefix}[${index}]`));
  } else if (value != null && typeof value === 'object') {
    Object.entries(value as Record<string, unknown>).forEach(([key, val]) =>
      appendMoodleParams(body, val, prefix ? `${prefix}[${key}]` : key),
    );
  } else if (value != null) {
    body.set(prefix, String(value));
  }
}
