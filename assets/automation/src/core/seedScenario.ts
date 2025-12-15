import fs from 'node:fs';
import path from 'node:path';
import { APIRequestContext } from '@playwright/test';

export type SeedScenarioResponse = {
  ok: boolean;
  outputs?: Record<string, unknown>;
  summary?: Record<string, unknown>;
};

const SCENARIO_ENDPOINT = '/test/scenario-yaml';

export async function seedScenarioFromFile(
  request: APIRequestContext,
  scenarioFilePath: string,
  params: Record<string, unknown> = {},
  baseUrl: string,
  token: string,
): Promise<SeedScenarioResponse> {
  const absolutePath = path.resolve(scenarioFilePath);
  const yaml = fs.readFileSync(absolutePath, 'utf8');

  const targetUrl = new URL(SCENARIO_ENDPOINT, baseUrl).toString();

  const response = await request.post(targetUrl, {
    headers: {
      'x-playwright-scenario-token': token,
      'content-type': 'application/json',
    },
    data: { yaml, params },
  });

  if (!response.ok()) {
    const body = await response.text();
    throw new Error(`Scenario seed request failed (${response.status()}): ${body}`);
  }

  const payload = (await response.json()) as SeedScenarioResponse;

  if (!payload.ok) {
    throw new Error(`Scenario seed execution failed: ${JSON.stringify(payload)}`);
  }

  return payload;
}
