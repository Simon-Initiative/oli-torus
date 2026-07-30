import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { APIRequestContext } from '@playwright/test';
import { getScenarioToken } from '@core/runtimeConfig';

export async function fetchTestAsset(
  request: APIRequestContext,
  key: string,
  baseUrl: string,
): Promise<Buffer> {
  const url = new URL(`/test/assets/${key}`, baseUrl).toString();
  const response = await request.get(url, {
    headers: { 'x-playwright-scenario-token': getScenarioToken() },
  });

  if (!response.ok()) {
    throw new Error(`Failed to download test asset (${response.status()}): ${url}`);
  }

  return response.body();
}

export async function fetchTestArchiveToTempFile(
  key: string,
  baseUrl: string,
): Promise<{ filePath: string; tempDir: string }> {
  const url = new URL(`/test/assets/${key}`, baseUrl).toString();
  const response = await fetch(url, {
    headers: { 'x-playwright-scenario-token': getScenarioToken() },
  });

  if (!response.ok) {
    throw new Error(`Failed to download test asset (${response.status}): ${url}`);
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'torus-qa-asset-'));
  try {
    const filePath = path.join(tempDir, path.basename(key));
    await fs.writeFile(filePath, buffer);
    return { filePath, tempDir };
  } catch (e) {
    await fs.rm(tempDir, { recursive: true, force: true }).catch(() => {});
    throw e;
  }
}
