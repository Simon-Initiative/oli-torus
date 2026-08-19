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
const originalTeardownTimeout = process.env.PLAYWRIGHT_AUTOMATION_TEARDOWN_TIMEOUT_MS;

function stubRequest(response: {
  ok: boolean;
  status?: number;
  json?: unknown;
  text?: string;
}): APIRequestContext & { postOptions: unknown[] } {
  const postOptions: unknown[] = [];

  return {
    postOptions,
    post: async (_url: string, options: unknown) => {
      postOptions.push(options);

      return {
        ok: () => response.ok,
        status: () => response.status ?? (response.ok ? 200 : 500),
        json: async () => {
          if (response.json === undefined) throw new Error('invalid JSON');
          return response.json;
        },
        text: async () => response.text ?? '',
      };
    },
  } as unknown as APIRequestContext & { postOptions: unknown[] };
}

function stubFailingRequest(error: Error): APIRequestContext {
  return {
    post: async () => {
      throw error;
    },
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
  delete process.env.PLAYWRIGHT_AUTOMATION_TEARDOWN_TIMEOUT_MS;
  warnings = [];
  console.warn = (...args: unknown[]) => {
    warnings.push(args.map(String).join(' '));
  };
});

test.afterEach(() => {
  if (originalTeardownTimeout === undefined) {
    delete process.env.PLAYWRIGHT_AUTOMATION_TEARDOWN_TIMEOUT_MS;
  } else {
    process.env.PLAYWRIGHT_AUTOMATION_TEARDOWN_TIMEOUT_MS = originalTeardownTimeout;
  }
  console.warn = originalWarn;
});

test('all-success payload emits no warnings', async () => {
  const request = stubRequest({ ok: true, json: allSuccess });

  await teardownAutomationCourse(request, seeded, options);

  expect(warnings).toEqual([]);
  expect(request.postOptions[0]).toMatchObject({ timeout: 10_000 });
});

test('teardown timeout can be overridden by environment variable', async () => {
  process.env.PLAYWRIGHT_AUTOMATION_TEARDOWN_TIMEOUT_MS = '2500';
  const request = stubRequest({ ok: true, json: allSuccess });

  await teardownAutomationCourse(request, seeded, options);

  expect(request.postOptions[0]).toMatchObject({ timeout: 2500 });
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

test('request errors warn without failing the test', async () => {
  await teardownAutomationCourse(stubFailingRequest(new Error('socket hang up')), seeded, options);

  expect(warnings).toHaveLength(1);
  expect(warnings[0]).toContain('automation_teardown request failed');
  expect(warnings[0]).toContain('project=proj-slug section=sect-slug');
  expect(warnings[0]).toContain('socket hang up');
});
