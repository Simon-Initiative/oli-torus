import { type APIRequestContext } from '@playwright/test';
import { load as parseYaml } from 'js-yaml';

const DEFAULT_CONFIG_URL_ENV = 'PLAYWRIGHT_PARAMETER_CONFIG_URL';

type SharedParameterConfig = {
  target?: unknown;
  tests?: unknown;
};

export type ParameterizedTestConfig<T> = {
  baseUrl: string;
  scenarioToken?: string;
  parameters: T;
};

export async function loadParameterizedTestConfig<T>(
  request: APIRequestContext,
  testCaseName: string,
  substitutions: Record<string, string> = {},
  configUrlEnv = DEFAULT_CONFIG_URL_ENV,
): Promise<ParameterizedTestConfig<T>> {
  const configUrl = requiredEnvironmentVariable(configUrlEnv);
  validateConfigUrl(configUrl, configUrlEnv);

  const response = await request.get(configUrl);

  if (!response.ok()) {
    throw new Error(
      `Unable to download Playwright parameter configuration from ${configUrlEnv} ` +
        `(${response.status()} ${response.statusText()})`,
    );
  }

  const parsed = parseYaml(await response.text()) as SharedParameterConfig;
  const config = requireRecord(parsed, 'configuration root');
  const target = requireRecord(config.target, 'target');
  const tests = requireRecord(config.tests, 'tests');
  const testParameters = requireRecord(tests[testCaseName], `tests.${testCaseName}`);

  return {
    baseUrl: normalizeBaseUrl(requireString(target.base_url, 'target.base_url')),
    scenarioToken: optionalString(target.scenario_token, 'target.scenario_token'),
    parameters: interpolateValues(testParameters, substitutions) as T,
  };
}

function requiredEnvironmentVariable(name: string) {
  const value = process.env[name]?.trim();

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function validateConfigUrl(value: string, environmentVariable: string) {
  let url: URL;

  try {
    url = new URL(value);
  } catch {
    throw new Error(`${environmentVariable} must contain a valid URL`);
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error(`${environmentVariable} must use http or https`);
  }
}

function normalizeBaseUrl(value: string) {
  let url: URL;

  try {
    url = new URL(value);
  } catch {
    throw new Error('target.base_url must contain a valid URL');
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('target.base_url must use http or https');
  }

  return url.toString().replace(/\/$/, '');
}

function requireRecord(value: unknown, path: string): Record<string, unknown> {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`Playwright parameter configuration field '${path}' must be a map`);
  }

  return value as Record<string, unknown>;
}

function requireString(value: unknown, path: string) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(
      `Playwright parameter configuration field '${path}' must be a non-empty string`,
    );
  }

  return value;
}

function optionalString(value: unknown, path: string) {
  if (value === undefined) return undefined;
  return requireString(value, path);
}

function interpolateValues(value: unknown, substitutions: Record<string, string>): unknown {
  if (typeof value === 'string') {
    return Object.entries(substitutions).reduce(
      (interpolated, [name, replacement]) => interpolated.split(`\${${name}}`).join(replacement),
      value,
    );
  }

  if (Array.isArray(value)) {
    return value.map((item) => interpolateValues(item, substitutions));
  }

  if (value != null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, interpolateValues(item, substitutions)]),
    );
  }

  return value;
}
