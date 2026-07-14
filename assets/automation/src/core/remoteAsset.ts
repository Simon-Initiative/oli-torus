import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

/**
 * Resolve a test asset reference to a local file path.
 *
 * Accepts either a filesystem path (returned as-is) or an http(s) URL —
 * e.g. an S3 presigned URL for assets that cannot be committed to the repo —
 * which is downloaded once per run into a temp directory.
 */
export async function resolveAssetToFile(pathOrUrl: string): Promise<string> {
  if (!/^https?:\/\//i.test(pathOrUrl)) {
    // expand a leading ~ — env files often reference assets under $HOME
    const localPath = pathOrUrl.startsWith('~/')
      ? path.join(os.homedir(), pathOrUrl.slice(2))
      : pathOrUrl;
    return path.resolve(localPath);
  }

  const response = await fetch(pathOrUrl);
  if (!response.ok) {
    throw new Error(
      `Failed to download test asset (${response.status}): ${pathOrUrl.split('?')[0]}`,
    );
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  const name = path.basename(new URL(pathOrUrl).pathname) || 'asset';
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'torus-qa-asset-'));
  const filePath = path.join(dir, name);
  await fs.writeFile(filePath, buffer);
  return filePath;
}
