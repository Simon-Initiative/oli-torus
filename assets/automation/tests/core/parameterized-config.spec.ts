import { loadParameterizedTestConfig } from '@core/parameterizedConfig';
import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { APIRequestContext, expect, test } from '@playwright/test';
import { createServer } from 'node:http';

const CONFIG_URL_ENV = 'PARAMETERIZED_CONFIG_TEST_URL';
const originalConfigUrl = process.env[CONFIG_URL_ENV];

test.afterEach(() => {
  resetRuntimeConfig();
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

test('authenticates private Torus assets and refuses redirects', async ({ request }) => {
  const received: { path: string; token: string | string[] | undefined }[] = [];
  const server = createServer((req, res) => {
    received.push({ path: req.url!, token: req.headers['x-playwright-scenario-token'] });
    if (req.url === '/test/assets/redirect.yaml') {
      res.writeHead(302, { Location: '/redirect-target' });
      res.end();
    } else {
      res.end('target:\n  base_url: https://torus.example.test\ntests:\n  dot_chatbot: {}');
    }
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('Expected TCP server address');
    const origin = `http://127.0.0.1:${address.port}`;
    setRuntimeConfig({ baseUrl: origin, scenarioToken: 'test-scenario-token' });
    process.env[CONFIG_URL_ENV] = `${origin}/test/assets/config.yaml`;
    await loadParameterizedTestConfig(request, 'dot_chatbot', {}, CONFIG_URL_ENV);

    process.env[CONFIG_URL_ENV] = `${origin}/test/assets/redirect.yaml`;
    await expect(
      loadParameterizedTestConfig(request, 'dot_chatbot', {}, CONFIG_URL_ENV),
    ).rejects.toThrow('(302 Found)');

    expect(received).toEqual([
      { path: '/test/assets/config.yaml', token: 'test-scenario-token' },
      { path: '/test/assets/redirect.yaml', token: 'test-scenario-token' },
    ]);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
});

for (const url of [
  'https://config.example.test/test/assets/config.yaml',
  'https://torus.example.test/config.yaml',
  'https://torus.example.test/test/assets-other/config.yaml',
  'http://torus.example.test/test/assets/config.yaml',
]) {
  test(`does not send the scenario token to ${url}`, async () => {
    setRuntimeConfig({ baseUrl: 'https://torus.example.test', scenarioToken: 'private-token' });
    process.env[CONFIG_URL_ENV] = url;
    let options: unknown;
    const request = requestReturning(
      'target:\n  base_url: https://torus.example.test\ntests:\n  dot_chatbot: {}',
      {},
      (requestOptions) => {
        options = requestOptions;
      },
    );
    await loadParameterizedTestConfig(request, 'dot_chatbot', {}, CONFIG_URL_ENV);
    expect(options).toBeUndefined();
  });
}

test('omits credentials from request and YAML parsing failures', async () => {
  process.env[CONFIG_URL_ENV] = 'https://torus.example.test/test/assets/config.yaml';
  setRuntimeConfig({ baseUrl: 'https://torus.example.test', scenarioToken: 'private-token' });
  const request = {
    get: async () => {
      throw new Error('request headers: private-token');
    },
  } as unknown as APIRequestContext;
  await expect(
    loadParameterizedTestConfig(request, 'dot_chatbot', {}, CONFIG_URL_ENV),
  ).rejects.toThrow(
    new Error(`Unable to download Playwright parameter configuration from ${CONFIG_URL_ENV}`),
  );
  await expect(
    loadParameterizedTestConfig(
      requestReturning('token: [private-token'),
      'dot_chatbot',
      {},
      CONFIG_URL_ENV,
    ),
  ).rejects.toThrow(
    new Error(`Invalid YAML in Playwright parameter configuration from ${CONFIG_URL_ENV}`),
  );
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
  onGet?: (options: unknown) => void,
) {
  return {
    get: async (_url: string, options: unknown) => {
      onGet?.(options);
      return {
        ok: () => response.ok ?? true,
        status: () => response.status ?? 200,
        statusText: () => response.statusText ?? 'OK',
        text: async () => body,
      };
    },
  } as unknown as APIRequestContext;
}
