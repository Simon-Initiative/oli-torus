import { loadParameterizedTestConfig } from '@core/parameterizedConfig';
import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { TYPE_USER } from '@pom/types/type-user';
import { expect } from '@playwright/test';

const TEST_CASE_NAME = 'dot_chatbot';
const SCENARIO_PATH = './dot-chatbot.scenario.yaml';
const KNOWN_DOT_FAILURE_MESSAGE =
  'Hmmm, we encountered a problem while processing your last message. Maybe try again later.';
const runId = `${Date.now()}-${process.pid}`;

type DotChatbotParameters = {
  course: {
    page_title: string;
    project_name?: string;
    project_title?: string;
    section_name?: string;
    section_slug?: string;
    section_title?: string;
  };
  dot: {
    prompt: string;
    response_timeout_ms: number;
    service_config_name?: string;
  };
  setup: {
    mode: 'existing' | 'scenario';
  };
  student: {
    email: string;
    family_name: string;
    given_name: string;
    name: string;
    password: string;
  };
};

let baseUrl: string;
let parameters: DotChatbotParameters;
let sectionSlug: string;

test.use({ trace: 'off' });

test.beforeAll(async ({ request, seedScenario }) => {
  const loaded = await loadParameterizedTestConfig<DotChatbotParameters>(request, TEST_CASE_NAME, {
    RUN_ID: runId,
  });

  baseUrl = loaded.baseUrl;
  parameters = validateParameters(loaded.parameters);

  setRuntimeConfig({
    baseUrl,
    scenarioToken: loaded.scenarioToken,
    loginData: {
      student: {
        type: TYPE_USER.student,
        pageTitle: 'OLI Torus',
        role: 'Student',
        welcomeText: 'Welcome to OLI Torus',
        welcomeTitle: `Hi, ${parameters.student.given_name}`,
        email: parameters.student.email,
        name: parameters.student.given_name,
        last_name: parameters.student.family_name,
        pass: parameters.student.password,
      },
    },
  });

  if (parameters.setup.mode === 'scenario') {
    if (!loaded.scenarioToken) {
      throw new Error('target.scenario_token is required when setup.mode is scenario');
    }

    const result = await seedScenario(SCENARIO_PATH, scenarioParameters(parameters));
    const sections = result.outputs?.sections as Record<string, string> | undefined;
    const users = result.outputs?.users as Record<string, string> | undefined;
    const sectionName = requiredScenarioParameter(
      parameters.course.section_name,
      'course.section_name',
    );

    sectionSlug = sections?.[sectionName] ?? '';

    expect(sectionSlug).toBeTruthy();
    expect(users?.[parameters.student.name]).toBe(parameters.student.email);
  } else {
    sectionSlug = requiredScenarioParameter(parameters.course.section_slug, 'course.section_slug');
  }
});

test.afterAll(() => resetRuntimeConfig());

test.describe('Dot chatbot @nightly @smoke', () => {
  test('an enrolled student receives a completed streamed response', async ({
    homeTask,
    page,
  }, testInfo) => {
    testInfo.setTimeout(parameters.dot.response_timeout_ms + 60_000);

    await homeTask.login('student');
    await page.goto(courseLearnUrl(baseUrl, sectionSlug), { waitUntil: 'load' });

    const studentCourse = new StudentCoursePO(page);
    await studentCourse.goToCourseIfPrompted();
    await studentCourse.openFirstPage(parameters.course.page_title);

    const collapsedDot = page.getByRole('button', { name: 'Dot AI' });
    const input = page.locator('#ai_bot_input');

    await expect(collapsedDot).toBeVisible();
    await collapsedDot.click();
    await expect(input).toBeVisible();

    const assistantCopyButtons = page.locator(
      '#message-container [data-clipboard-target^="#message_"]:not([data-clipboard-target="#message_0_content"])',
    );
    const baselineAssistantCount = await assistantCopyButtons.count();

    await input.fill(parameters.dot.prompt);
    await page.getByRole('button', { name: 'submit message' }).click();

    await expect(input).toBeDisabled({ timeout: 10_000 });
    await expect(input).toBeEnabled({ timeout: parameters.dot.response_timeout_ms });
    await expect
      .poll(() => assistantCopyButtons.count(), { timeout: 10_000 })
      .toBeGreaterThan(baselineAssistantCount);

    const newAssistantCopyButton = assistantCopyButtons.nth(baselineAssistantCount);
    await expect(newAssistantCopyButton).toBeVisible();

    const responseTarget = await newAssistantCopyButton.getAttribute('data-clipboard-target');
    expect(responseTarget).toMatch(/^#message_\d+_content$/);

    const assistantResponse = page.locator(responseTarget as string);
    await expect(assistantResponse).toContainText(/\S/);
    await expect(assistantResponse).not.toContainText(KNOWN_DOT_FAILURE_MESSAGE);
  });
});

function scenarioParameters(config: DotChatbotParameters) {
  return {
    PROJECT_NAME: requiredScenarioParameter(config.course.project_name, 'course.project_name'),
    PROJECT_TITLE: requiredScenarioParameter(config.course.project_title, 'course.project_title'),
    PAGE_TITLE: config.course.page_title,
    SECTION_NAME: requiredScenarioParameter(config.course.section_name, 'course.section_name'),
    SECTION_TITLE: requiredScenarioParameter(config.course.section_title, 'course.section_title'),
    STUDENT_NAME: config.student.name,
    STUDENT_EMAIL: config.student.email,
    STUDENT_GIVEN_NAME: config.student.given_name,
    STUDENT_FAMILY_NAME: config.student.family_name,
    password: config.student.password,
    ASSISTANT_SERVICE_CONFIG: requiredScenarioParameter(
      config.dot.service_config_name,
      'dot.service_config_name',
    ),
  };
}

function courseLearnUrl(targetBaseUrl: string, targetSectionSlug: string) {
  return new URL(
    `/sections/${encodeURIComponent(targetSectionSlug)}/learn?sidebar_expanded=true&selected_view=outline`,
    targetBaseUrl,
  ).toString();
}

function validateParameters(config: DotChatbotParameters) {
  const requiredStrings = {
    'course.page_title': config?.course?.page_title,
    'dot.prompt': config?.dot?.prompt,
    'setup.mode': config?.setup?.mode,
    'student.email': config?.student?.email,
    'student.family_name': config?.student?.family_name,
    'student.given_name': config?.student?.given_name,
    'student.name': config?.student?.name,
    'student.password': config?.student?.password,
  };

  Object.entries(requiredStrings).forEach(([path, value]) => {
    if (typeof value !== 'string' || value.trim() === '') {
      throw new Error(`tests.${TEST_CASE_NAME}.${path} must be a non-empty string`);
    }
  });

  if (!['existing', 'scenario'].includes(config.setup.mode)) {
    throw new Error(`tests.${TEST_CASE_NAME}.setup.mode must be existing or scenario`);
  }

  const setupSpecificStrings =
    config.setup.mode === 'scenario'
      ? {
          'course.project_name': config.course.project_name,
          'course.project_title': config.course.project_title,
          'course.section_name': config.course.section_name,
          'course.section_title': config.course.section_title,
          'dot.service_config_name': config.dot.service_config_name,
        }
      : { 'course.section_slug': config.course.section_slug };

  Object.entries(setupSpecificStrings).forEach(([path, value]) => {
    requiredScenarioParameter(value, path);
  });

  if (!Number.isInteger(config?.dot?.response_timeout_ms) || config.dot.response_timeout_ms <= 0) {
    throw new Error(`tests.${TEST_CASE_NAME}.dot.response_timeout_ms must be a positive integer`);
  }

  return config;
}

function requiredScenarioParameter(value: string | undefined, path: string) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`tests.${TEST_CASE_NAME}.${path} must be a non-empty string`);
  }

  return value;
}
