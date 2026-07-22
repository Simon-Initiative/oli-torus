import { loadParameterizedTestConfig } from '@core/parameterizedConfig';
import { APIRequestContext, expect, test } from '@playwright/test';

const CONFIG_URL_ENV = 'PARAMETERIZED_CONFIG_TEST_URL';
const originalConfigUrl = process.env[CONFIG_URL_ENV];

test.afterEach(() => {
  if (originalConfigUrl === undefined) {
    delete process.env[CONFIG_URL_ENV];
  } else {
    process.env[CONFIG_URL_ENV] = originalConfigUrl;
  }
});

test('downloads, selects, and interpolates a parameterized test configuration', async () => {
  process.env[CONFIG_URL_ENV] = 'https://config.example.test/smoke.yaml';
  const request = requestReturning(`
target:
  base_url: https://torus.example.test/
  scenario_token: scenario-secret
tests:
  dot_chatbot:
    section_name: dot_section_\${RUN_ID}
    nested:
      - dot_student_\${RUN_ID}
`);

  const loaded = await loadParameterizedTestConfig<Record<string, unknown>>(
    request,
    'dot_chatbot',
    { RUN_ID: '123' },
    CONFIG_URL_ENV,
  );

  expect(loaded).toEqual({
    baseUrl: 'https://torus.example.test',
    scenarioToken: 'scenario-secret',
    parameters: {
      section_name: 'dot_section_123',
      nested: ['dot_student_123'],
    },
  });
});

test('allows configuration without a scenario token for existing-data smoke tests', async () => {
  process.env[CONFIG_URL_ENV] = 'https://config.example.test/smoke.yaml';
  const request = requestReturning(`
target:
  base_url: https://torus.example.test
tests:
  dot_chatbot:
    setup:
      mode: existing
`);

  const loaded = await loadParameterizedTestConfig<Record<string, unknown>>(
    request,
    'dot_chatbot',
    {},
    CONFIG_URL_ENV,
  );

  expect(loaded.scenarioToken).toBeUndefined();
});

test('rejects a missing configuration URL', async () => {
  delete process.env[CONFIG_URL_ENV];

  await expect(
    loadParameterizedTestConfig(requestReturning(''), 'dot_chatbot', {}, CONFIG_URL_ENV),
  ).rejects.toThrow(`Missing required environment variable: ${CONFIG_URL_ENV}`);
});

test('rejects a non-http configuration URL', async () => {
  process.env[CONFIG_URL_ENV] = 'file:///tmp/smoke.yaml';

  await expect(
    loadParameterizedTestConfig(requestReturning(''), 'dot_chatbot', {}, CONFIG_URL_ENV),
  ).rejects.toThrow(`${CONFIG_URL_ENV} must use http or https`);
});

test('reports configuration download failures', async () => {
  process.env[CONFIG_URL_ENV] = 'https://config.example.test/smoke.yaml';
  const request = requestReturning('', { ok: false, status: 503, statusText: 'Unavailable' });

  await expect(
    loadParameterizedTestConfig(request, 'dot_chatbot', {}, CONFIG_URL_ENV),
  ).rejects.toThrow(`from ${CONFIG_URL_ENV} (503 Unavailable)`);
});

test('rejects malformed YAML and missing test cases', async () => {
  process.env[CONFIG_URL_ENV] = 'https://config.example.test/smoke.yaml';

  await expect(
    loadParameterizedTestConfig(requestReturning('tests: ['), 'dot_chatbot', {}, CONFIG_URL_ENV),
  ).rejects.toThrow();

  await expect(
    loadParameterizedTestConfig(
      requestReturning(`
target:
  base_url: https://torus.example.test
tests: {}
`),
      'dot_chatbot',
      {},
      CONFIG_URL_ENV,
    ),
  ).rejects.toThrow("field 'tests.dot_chatbot' must be a map");
});

function requestReturning(
  body: string,
  response: { ok?: boolean; status?: number; statusText?: string } = {},
) {
  return {
    get: async () => ({
      ok: () => response.ok ?? true,
      status: () => response.status ?? 200,
      statusText: () => response.statusText ?? 'OK',
      text: async () => body,
    }),
  } as unknown as APIRequestContext;
}
