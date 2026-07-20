import { expect, type Page, type Route } from '@playwright/test';
import { type SeedScenarioResponse } from '@core/seedScenario';
import { getBaseUrl, getScenarioToken } from '@core/runtimeConfig';

export type StudentPaymentScenarioOutputs = {
  params?: Record<string, string>;
  sections?: Record<string, string>;
  users?: Record<string, string>;
};

export type SeededScenarioUser = {
  sectionSlug: string;
  userEmail: string;
};

export type PostJsonResult<T> = {
  status: number;
  body: T;
};

export type PostResponse = {
  status: number;
  body: unknown;
  text: string;
  contentType: string | null;
};

// Scenario seeding helpers used to resolve stable section and user outputs.
export async function seedStudentPaymentScenario(
  seedScenario: (
    relativePath: string,
    params?: Record<string, unknown>,
  ) => Promise<SeedScenarioResponse>,
  scenarioPath: string,
  runId: string,
): Promise<StudentPaymentScenarioOutputs> {
  const response = await seedScenario(scenarioPath, { RUN_ID: runId });
  const outputs = response.outputs as StudentPaymentScenarioOutputs | undefined;

  if (!outputs) {
    throw new Error('Scenario did not return outputs');
  }

  return outputs;
}

export async function seedScenarioUser(
  seedScenario: (
    relativePath: string,
    params?: Record<string, unknown>,
  ) => Promise<SeedScenarioResponse>,
  scenarioPath: string,
  runId: string,
  sectionKey: string,
  userKey: string,
): Promise<SeededScenarioUser> {
  const outputs = await seedStudentPaymentScenario(seedScenario, scenarioPath, runId);

  const sectionSlug = outputs.sections?.[sectionKey] ?? '';
  const userEmail = outputs.users?.[userKey] ?? outputs.params?.[userKey] ?? '';

  if (!sectionSlug) {
    throw new Error(`Scenario did not return section output '${sectionKey}'`);
  }

  if (!userEmail) {
    throw new Error(`Scenario did not return user output '${userKey}'`);
  }

  return { sectionSlug, userEmail };
}

// Browser-side auth and POST helpers keep payment flows inside the real session context.
export async function logInAsScenarioUser(
  page: Page,
  email: string,
  requestPath = '/',
  expectedPath = requestPath,
) {
  const baseUrl = getBaseUrl();
  const scenarioToken = getScenarioToken();
  const loginUrl = new URL('/test/log_in_user', baseUrl);

  loginUrl.searchParams.set('email', email);
  loginUrl.searchParams.set('request_path', requestPath);
  await withScenarioTokenOnLoginRequest(page, loginUrl, scenarioToken, async () => {
    await page.goto(loginUrl.toString(), { waitUntil: 'load' });
    await expect(page).toHaveURL(new RegExp(escapeRegExp(expectedPath)));
  });
}

export async function postJsonInBrowser<T>(
  page: Page,
  path: string,
  payload: Record<string, unknown>,
): Promise<PostJsonResult<T>> {
  const result = await postInBrowser(page, path, payload);
  return { status: result.status, body: result.body as T };
}

export async function postInBrowser(
  page: Page,
  path: string,
  payload: Record<string, unknown>,
): Promise<PostResponse> {
  return await page.evaluate(
    async ({ path, payload }) => {
      const response = await fetch(path, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(payload),
        credentials: 'same-origin',
      });

      const contentType = response.headers.get('content-type');
      const text = await response.text();

      let body: unknown = text;

      if (contentType?.includes('application/json')) {
        body = JSON.parse(text);
      }

      return { status: response.status, body, text, contentType };
    },
    { path, payload },
  );
}

// Payment code redemption still goes through the real form flow, including the recaptcha field.
export async function submitPaymentCode(page: Page, code: string) {
  await page.locator('input[name="code[value]"]').fill(code);

  await page.evaluate(() => {
    const form = document.querySelector<HTMLFormElement>('form[action*="/payment/code"]');
    if (form == null) return;

    document
      .querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('[name="g-recaptcha-response"]')
      .forEach((response) => {
        response.value = 'playwright-test-token';
      });

    const response = document.createElement('input');
    response.type = 'hidden';
    response.name = 'g-recaptcha-response';
    response.value = 'playwright-test-token';
    form.appendChild(response);
  });

  await page.getByRole('button', { name: 'Submit' }).click();
}

async function withScenarioTokenOnLoginRequest(
  page: Page,
  loginUrl: URL,
  scenarioToken: string,
  action: () => Promise<void>,
) {
  const loginUrlPattern = `${loginUrl.toString()}**`;
  const addScenarioTokenToLoginRequest = async (route: Route) => {
    await route.fallback({
      headers: {
        ...route.request().headers(),
        'x-playwright-scenario-token': scenarioToken,
      },
    });
  };

  await page.route(loginUrlPattern, addScenarioTokenToLoginRequest);

  try {
    await action();
  } finally {
    await page.unroute(loginUrlPattern, addScenarioTokenToLoginRequest);
  }
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
