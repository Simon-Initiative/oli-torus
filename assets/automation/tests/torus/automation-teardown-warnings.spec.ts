import { APIRequestContext, expect, test } from '@playwright/test';
import { AutomationSetupResponse, teardownAutomationCourse } from '@tasks/AutomationSetupTask';

const seeded: AutomationSetupResponse = {
  success: true,
  author: { email: 'author@example.com', password: 'pw' },
  educator: { email: 'educator@example.com', password: 'pw' },
  learner: { email: 'learner@example.com', password: 'pw' },
  project: { slug: 'proj-slug', title: 'Project' },
  section: { slug: 'sect-slug' },
};

const options = { baseUrl: 'http://localhost', apiKey: 'key' };

function stubRequest(response: {
  ok: boolean;
  status?: number;
  json?: unknown;
  text?: string;
}): APIRequestContext {
  return {
    post: async () => ({
      ok: () => response.ok,
      status: () => response.status ?? (response.ok ? 200 : 500),
      json: async () => {
        if (response.json === undefined) throw new Error('invalid JSON');
        return response.json;
      },
      text: async () => response.text ?? '',
    }),
  } as unknown as APIRequestContext;
}

const allSuccess = {
  author_deleted: { success: true },
  educator_deleted: { success: true },
  learner_deleted: { success: true },
  section_deleted: { success: true },
  project_deleted: { success: true },
};

let warnings: string[];
const originalWarn = console.warn;

test.beforeEach(() => {
  warnings = [];
  console.warn = (...args: unknown[]) => {
    warnings.push(args.map(String).join(' '));
  };
});

test.afterEach(() => {
  console.warn = originalWarn;
});

test('all-success payload emits no warnings', async () => {
  await teardownAutomationCourse(stubRequest({ ok: true, json: allSuccess }), seeded, options);
  expect(warnings).toEqual([]);
});

test('partial failure warns once naming failed entities, messages, and slugs', async () => {
  await teardownAutomationCourse(
    stubRequest({
      ok: true,
      json: {
        ...allSuccess,
        section_deleted: { success: false, message: 'Could not delete section' },
        project_deleted: { success: false },
      },
    }),
    seeded,
    options,
  );
  expect(warnings).toHaveLength(1);
  expect(warnings[0]).toContain('project=proj-slug section=sect-slug');
  expect(warnings[0]).toContain('section_deleted: Could not delete section');
  expect(warnings[0]).toContain('project_deleted: no message');
  expect(warnings[0]).not.toContain('author_deleted');
});

test('invalid JSON body warns as unreadable without rejecting', async () => {
  await teardownAutomationCourse(
    stubRequest({ ok: true, text: 'not json at all' }),
    seeded,
    options,
  );
  expect(warnings).toHaveLength(1);
  expect(warnings[0]).toContain('unreadable payload');
  expect(warnings[0]).toContain('not json at all');
});

test('non-object JSON payloads warn as unreadable', async () => {
  for (const json of [null, 'string', 42, [1, 2]]) {
    warnings = [];
    await teardownAutomationCourse(stubRequest({ ok: true, json }), seeded, options);
    expect(warnings).toHaveLength(1);
    expect(warnings[0]).toContain('unreadable payload');
  }
});

test('missing or malformed entity results warn per entity', async () => {
  await teardownAutomationCourse(
    stubRequest({
      ok: true,
      json: { author_deleted: { success: true }, project_deleted: null },
    }),
    seeded,
    options,
  );
  expect(warnings).toHaveLength(1);
  expect(warnings[0]).toContain('educator_deleted: missing or malformed result');
  expect(warnings[0]).toContain('learner_deleted: missing or malformed result');
  expect(warnings[0]).toContain('section_deleted: missing or malformed result');
  expect(warnings[0]).toContain('project_deleted: missing or malformed result');
  expect(warnings[0]).not.toContain('author_deleted');
});

test('non-2xx response keeps existing warning path and skips payload parsing', async () => {
  await teardownAutomationCourse(
    stubRequest({ ok: false, status: 500, text: 'boom' }),
    seeded,
    options,
  );
  expect(warnings).toHaveLength(1);
  expect(warnings[0]).toContain('automation_teardown failed (500)');
  expect(warnings[0]).toContain('boom');
});
