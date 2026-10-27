import { test as fixtureTest } from '@fixture/my-fixture';
import { SimpleAuthorPO } from '@pom/page/SimpleAuthorPO';
import { expect, Page } from '@playwright/test';

const origin = 'http://simple-author.test';
const saveUrl = `${origin}/api/v1/project/save-test/resource/1`;

// These page-object checks intercept browser requests and need no Torus server
// or seeded data. Replace the shared fixture's automatic site navigation.
const test = fixtureTest.extend({
  forEachTest: async ({ page }, use) => {
    await page.route(`${origin}/`, (route) =>
      route.fulfill({
        contentType: 'text/html',
        body: '<!doctype html><title>Save checks</title>',
      }),
    );
    await page.goto(`${origin}/`);
    await use();
  },
});

async function save(page: Page) {
  await page.evaluate(async (url) => {
    try {
      const response = await fetch(url, { method: 'PUT', body: '{}' });
      await response.text();
    } catch {
      // The page object, rather than fetch, must report transport failures.
    }
  }, saveUrl);
}

test.describe('Simple Author save diagnostics', { tag: '@pr' }, () => {
  test('accepts successful saves', async ({ page }) => {
    const editor = new SimpleAuthorPO(page);
    await page.route(saveUrl, (route) => route.fulfill({ status: 204 }));

    await save(page);

    await editor.waitForSaves();
  });

  test('reports HTTP errors even though the request completes', async ({ page }) => {
    const editor = new SimpleAuthorPO(page);
    await page.route(saveUrl, (route) => route.fulfill({ status: 500, body: 'Save failed' }));

    await save(page);

    await expect(editor.waitForSaves()).rejects.toThrow(`PUT ${saveUrl}: HTTP 500`);
    // A later call must not turn an earlier failed save into apparent success.
    await expect(editor.waitForSaves()).rejects.toThrow(`PUT ${saveUrl}: HTTP 500`);
  });

  test('reports aborted saves with the URL and network reason', async ({ page }) => {
    const editor = new SimpleAuthorPO(page);
    await page.route(saveUrl, (route) => route.abort('failed'));

    await save(page);

    await expect(editor.waitForSaves()).rejects.toThrow(`PUT ${saveUrl}: net::ERR_FAILED`);
  });

  test('keeps unfinished saves pending until they complete', async ({ page }) => {
    const editor = new SimpleAuthorPO(page);
    await page.route(saveUrl, async (route) => {
      try {
        await expect(editor.waitForSaves(100)).rejects.toThrow('(1 pending)');
      } finally {
        await route.fulfill({ status: 204 });
      }
    });

    await save(page);
    await editor.waitForSaves();
  });
});
