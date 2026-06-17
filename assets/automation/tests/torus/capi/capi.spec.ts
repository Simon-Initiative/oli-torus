import { expect, FrameLocator, Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import {
  CapiType,
  countOf,
  receivedMessages,
  sendFromStub,
  sendRawFromStub,
  sendValueChange,
  serveStubSim,
  startHandshake,
  stubFrame,
  STUB_SIM_URL,
} from './support/capiStub';

const SCENARIO = './capi_page.scenario.yaml';
const STUDENT_PASSWORD = 'changeme123456';

interface CapiContext {
  frame: FrameLocator;
  sectionSlug: string;
  pageSlug: string;
}

const attachConsole = (page: Page) => {
  page.on('console', (msg) => {
    if (msg.type() === 'error') console.log(`[browser:error] ${msg.text()}`);
  });
  page.on('pageerror', (err) => console.log(`[browser:pageerror] ${err.message}`));
};

const loginAsStudent = async (page: Page, email: string) => {
  await page.goto('/users/log_in');
  const acceptCookies = page.locator('#cookie_consent_display button:has-text("Accept")');
  if (await acceptCookies.isVisible({ timeout: 2000 }).catch(() => false)) {
    await acceptCookies.click();
  }
  await page.locator('#login_form_email').fill(email);
  await page.locator('#login_form_password').fill(STUDENT_PASSWORD);
  await page.locator('#login_form button:has-text("Sign in")').click();
  await page.waitForLoadState('networkidle');
};

const dismissOnboardingWizard = async (page: Page) => {
  const automationBypass = page.locator('#automation-go-to-course');
  for (let i = 0; i < 5; i++) {
    const onWizard =
      (await automationBypass.isVisible({ timeout: 3000 }).catch(() => false)) ||
      (await automationBypass.count()) > 0;
    if (!onWizard) break;
    await automationBypass.dispatchEvent('click');
    await page.waitForTimeout(1000);
  }
};

/** Returns the seeded lesson's revision slug (discovered from the Learn outline). */
const resolvePageSlug = async (page: Page, sectionSlug: string): Promise<string> => {
  await page.goto(`/sections/${sectionSlug}/learn`);
  const slug = await page.locator('[phx-value-slug]').first().getAttribute('phx-value-slug');
  expect(slug).toBeTruthy();
  return slug as string;
};

const visitLesson = async (page: Page, sectionSlug: string, pageSlug: string) => {
  await page.goto(`/sections/${sectionSlug}/lesson/${pageSlug}`);
  await expect(page.locator(`iframe[src="${STUB_SIM_URL}"]`)).toBeVisible({ timeout: 30_000 });
};

/** Seed a fresh section, log in as the student, and open the CAPI lesson. */
const setup = async (
  page: Page,
  seedScenario: (path: string, params: Record<string, unknown>) => Promise<any>,
): Promise<CapiContext> => {
  const runId = `capi${Date.now()}`;
  const seeded = await seedScenario(SCENARIO, { run_id: runId, stub_url: STUB_SIM_URL });
  const sectionSlug = seeded.outputs?.sections?.[`capi_section_${runId}`] as string;
  const studentEmail = seeded.outputs?.users?.[`capi_student_${runId}`] as string;
  expect(sectionSlug, 'seeded section slug').toBeTruthy();
  expect(studentEmail, 'seeded student email').toBeTruthy();

  attachConsole(page);
  await serveStubSim(page);
  await loginAsStudent(page, studentEmail);
  // First visit to the section surfaces the onboarding wizard; dismiss it, then
  // the outline (with the lesson's phx-value-slug) is reachable.
  await page.goto(`/sections/${sectionSlug}/learn`);
  await dismissOnboardingWizard(page);
  const pageSlug = await resolvePageSlug(page, sectionSlug);
  await visitLesson(page, sectionSlug, pageSlug);

  const frame = stubFrame(page);
  await expect(frame.locator('#status')).toContainText('stub-sim loaded');
  return { frame, sectionSlug, pageSlug };
};

const waitForCount = (frame: FrameLocator, type: CapiType, atLeast = 1) =>
  expect.poll(() => countOf(frame, type), { timeout: 15_000 }).toBeGreaterThanOrEqual(atLeast);

/** Drive the sim through handshake + ON_READY to a fully initialized state. */
const handshakeAndReady = async (frame: FrameLocator) => {
  await startHandshake(frame);
  await waitForCount(frame, CapiType.HANDSHAKE_RESPONSE);
  await sendFromStub(frame, CapiType.ON_READY);
  await waitForCount(frame, CapiType.INITIAL_SETUP_COMPLETE);
};

test.describe('CAPI delivery protocol', () => {
  // Test 1 — handshake
  test('completes handshake with the sim', async ({ page, seedScenario }) => {
    const { frame, sectionSlug } = await setup(page, seedScenario);

    await startHandshake(frame);
    await waitForCount(frame, CapiType.HANDSHAKE_RESPONSE);

    const [response] = await receivedMessages(frame, CapiType.HANDSHAKE_RESPONSE);
    expect(response.handshake.requestToken).toBe('stub-request-token');
    expect(response.handshake.config).toMatchObject({ context: 'VIEWER', sectionSlug });
    expect(response.handshake.config.userId).toBeTruthy();
    expect(response.handshake.config.questionId).toBeTruthy();
  });

  // Test 2 — init sequence (also exercises page -> sim VALUE_CHANGE for configData)
  test('pushes initial state then INITIAL_SETUP_COMPLETE after ON_READY', async ({
    page,
    seedScenario,
  }) => {
    const { frame } = await setup(page, seedScenario);

    await startHandshake(frame);
    await waitForCount(frame, CapiType.HANDSHAKE_RESPONSE);
    await sendFromStub(frame, CapiType.ON_READY);

    // Host pushes configData variables to the sim, then signals setup complete.
    await waitForCount(frame, CapiType.VALUE_CHANGE);
    await waitForCount(frame, CapiType.INITIAL_SETUP_COMPLETE);

    const valueChanges = await receivedMessages(frame, CapiType.VALUE_CHANGE);
    const carriesSeededVar = valueChanges.some(
      (m) => m.values && Object.prototype.hasOwnProperty.call(m.values, 'x'),
    );
    expect(carriesSeededVar, 'a VALUE_CHANGE carries the seeded "x" variable').toBe(true);
  });

  // Test 3 — check round-trip. The sim sets a variable then sends CHECK_REQUEST;
  // the host runs the deck check (CHECK_REQUEST -> part submit -> triggerCheck ->
  // lastCheckTriggered -> CHECK_STARTED/COMPLETE notifications) and replies to the
  // sim with CHECK_START_RESPONSE + CHECK_COMPLETE_RESPONSE. The seed includes a
  // non-navigating trapstate rule so evaluation returns rule-shaped results and the
  // completion half is not suppressed (navigation away would suppress CHECK_COMPLETE).
  test('runs the check lifecycle on CHECK_REQUEST', async ({ page, seedScenario }) => {
    const { frame } = await setup(page, seedScenario);
    await handshakeAndReady(frame);

    await sendValueChange(frame, { x: { type: 1, value: '5' } });
    await sendFromStub(frame, CapiType.CHECK_REQUEST);

    await waitForCount(frame, CapiType.CHECK_START_RESPONSE);
    await waitForCount(frame, CapiType.CHECK_COMPLETE_RESPONSE);

    // The rule (stage.capi_iframe_part.x == 5) fires a mutateState on `acknowledged`,
    // which the host pushes back to the sim — proving the CAPI variable reached and
    // satisfied evaluation (Kevin TC2 intent), not just that the check completed.
    await expect
      .poll(async () => {
        const changes = await receivedMessages(frame, CapiType.VALUE_CHANGE);
        return changes.some((m) => `${m.values?.acknowledged?.value}` === '1');
      }, { timeout: 15_000 })
      .toBe(true);
  });

  // Test 5 — state restore across a page revisit
  test('restores saved sim state on revisit', async ({ page, seedScenario }) => {
    const { frame, sectionSlug, pageSlug } = await setup(page, seedScenario);
    await handshakeAndReady(frame);

    // The save is observable only as the PATCH to the activity-attempt `/active` endpoint. Wait for
    // that response (started before the change) so we never navigate away before persistence —
    // deterministic, vs betting on a fixed sleep. No other save is in flight after handshakeAndReady.
    const saved = page.waitForResponse(
      (r) =>
        r.request().method() === 'PATCH' &&
        r.url().includes('/state/course/') &&
        r.url().includes('/active') &&
        r.ok(),
      { timeout: 30_000 },
    );
    await sendValueChange(frame, { x: { type: 1, value: '42' } });
    await saved;

    await visitLesson(page, sectionSlug, pageSlug);
    const frame2 = stubFrame(page);
    await expect(frame2.locator('#status')).toContainText('stub-sim loaded');

    await startHandshake(frame2);
    await waitForCount(frame2, CapiType.HANDSHAKE_RESPONSE);
    await sendFromStub(frame2, CapiType.ON_READY);
    await waitForCount(frame2, CapiType.VALUE_CHANGE);

    await expect
      .poll(
        async () => {
          const vcs = await receivedMessages(frame2, CapiType.VALUE_CHANGE);
          return vcs.some((m) => `${m.values?.x?.value}` === '42');
        },
        { timeout: 15_000 },
      )
      .toBe(true);
  });

  // Test 6 — SET_DATA round-trip (sim user storage)
  test('acknowledges SET_DATA_REQUEST with a success response', async ({ page, seedScenario }) => {
    const { frame } = await setup(page, seedScenario);
    await handshakeAndReady(frame);

    await sendFromStub(frame, CapiType.SET_DATA_REQUEST, {
      simId: 'miniFeeder',
      key: 'progress',
      value: 'step-1',
    });

    await waitForCount(frame, CapiType.SET_DATA_RESPONSE);
    const [resp] = await receivedMessages(frame, CapiType.SET_DATA_RESPONSE);
    expect(resp.values).toMatchObject({
      simId: 'miniFeeder',
      key: 'progress',
      responseType: 'success',
      value: 'step-1',
    });
  });

  // Test 7 — GET_DATA round-trip: stored value comes back; unknown key reports a miss
  test('returns stored data on GET_DATA_REQUEST and a miss for unknown keys', async ({
    page,
    seedScenario,
  }) => {
    const { frame } = await setup(page, seedScenario);
    await handshakeAndReady(frame);

    await sendFromStub(frame, CapiType.SET_DATA_REQUEST, {
      simId: 'miniFeeder',
      key: 'progress',
      value: 'step-2',
    });
    await waitForCount(frame, CapiType.SET_DATA_RESPONSE);

    await sendFromStub(frame, CapiType.GET_DATA_REQUEST, { simId: 'miniFeeder', key: 'progress' });
    await waitForCount(frame, CapiType.GET_DATA_RESPONSE);

    await expect
      .poll(async () => {
        const hits = await receivedMessages(frame, CapiType.GET_DATA_RESPONSE);
        return hits.some(
          (m) => m.values?.key === 'progress' && m.values?.exists === true && `${m.values?.value}`.includes('step-2'),
        );
      }, { timeout: 15_000 })
      .toBe(true);

    await sendFromStub(frame, CapiType.GET_DATA_REQUEST, { simId: 'miniFeeder', key: 'never-set' });
    await expect
      .poll(async () => {
        const hits = await receivedMessages(frame, CapiType.GET_DATA_RESPONSE);
        return hits.some((m) => m.values?.key === 'never-set' && m.values?.exists === false);
      }, { timeout: 15_000 })
      .toBe(true);
  });

  // Test 8 — RESIZE round-trip (absolute then relative), response echoes messageId
  test('responds to RESIZE_PARENT_CONTAINER_REQUEST (absolute and relative)', async ({
    page,
    seedScenario,
  }) => {
    const { frame } = await setup(page, seedScenario);
    await handshakeAndReady(frame);

    await sendFromStub(frame, CapiType.RESIZE_PARENT_CONTAINER_REQUEST, {
      messageId: 'resize-abs',
      width: { type: 'absolute', value: '500' },
      height: { type: 'absolute', value: '400' },
    });
    await expect
      .poll(async () => {
        const r = await receivedMessages(frame, CapiType.RESIZE_PARENT_CONTAINER_RESPONSE);
        return r.some((m) => m.values?.messageId === 'resize-abs' && m.values?.responseType === 'success');
      }, { timeout: 15_000 })
      .toBe(true);

    await sendFromStub(frame, CapiType.RESIZE_PARENT_CONTAINER_REQUEST, {
      messageId: 'resize-rel',
      width: { type: 'relative', value: '50' },
    });
    await expect
      .poll(async () => {
        const r = await receivedMessages(frame, CapiType.RESIZE_PARENT_CONTAINER_RESPONSE);
        return r.some((m) => m.values?.messageId === 'resize-rel' && m.values?.responseType === 'success');
      }, { timeout: 15_000 })
      .toBe(true);
  });

  // Test 9 — robustness: malformed and pre-handshake traffic must not break the listener
  test('survives malformed and pre-handshake messages, then handshakes normally', async ({
    page,
    seedScenario,
  }) => {
    const { frame } = await setup(page, seedScenario);

    // Garbage and out-of-order traffic before any handshake.
    await sendRawFromStub(frame, 'this is not json');
    await sendRawFromStub(frame, JSON.stringify({ foo: 'bar', no: 'type field' }));
    await sendValueChange(frame, { x: { type: 1, value: '9' } });

    // The listener must still be alive: a real handshake afterwards succeeds.
    await startHandshake(frame);
    await waitForCount(frame, CapiType.HANDSHAKE_RESPONSE);
    const [resp] = await receivedMessages(frame, CapiType.HANDSHAKE_RESPONSE);
    expect(resp.handshake.requestToken).toBe('stub-request-token');
  });

  // Test 10 — source check: a CAPI message from the main window (not the iframe) is ignored
  test('ignores a CAPI message posted from a foreign source', async ({ page, seedScenario }) => {
    const { frame } = await setup(page, seedScenario);

    // Post a well-formed HANDSHAKE_REQUEST from the top window. The host listener
    // filters on evnt.source === iframe.contentWindow, so this must be ignored.
    await page.evaluate(() => {
      window.postMessage(
        JSON.stringify({
          handshake: { requestToken: 'foreign-token', authToken: 'x', config: {} },
          options: {},
          type: 1,
          values: {},
        }),
        '*',
      );
    });

    // Wait past the 500ms handshake delay; the stub must NOT receive a response.
    await page.waitForTimeout(2000);
    expect(await countOf(frame, CapiType.HANDSHAKE_RESPONSE)).toBe(0);

    // A genuine handshake from the iframe still works -> only the foreign one was dropped.
    await startHandshake(frame);
    await waitForCount(frame, CapiType.HANDSHAKE_RESPONSE);
    const [resp] = await receivedMessages(frame, CapiType.HANDSHAKE_RESPONSE);
    expect(resp.handshake.requestToken).toBe('stub-request-token');
  });

  // Test 11 — characterization of the current listener boundary, NOT a desired security contract:
  // ExternalActivity filters by evnt.source but does not validate requestToken after handshake
  // (see the TODO in ExternalActivity.tsx and the MER-5701 CAPI findings). Pairs with test 10:
  // source is enforced; requestToken is not. If token validation is added later, replace this with
  // a negative assertion.
  test('documents current gap: same-iframe messages with a mismatched requestToken are still processed', async ({
    page,
    seedScenario,
  }) => {
    const { frame } = await setup(page, seedScenario);
    await handshakeAndReady(frame);

    // Side-effect-light request from the iframe, but with the WRONG token. `progress` was never
    // set for this fresh student, so the response should echo the request and report a miss.
    await sendFromStub(
      frame,
      CapiType.GET_DATA_REQUEST,
      { simId: 'miniFeeder', key: 'progress' },
      { requestToken: 'wrong-token' },
    );

    // Host still dispatches and responds despite the mismatched token, and the response is tied to
    // this request (echoed simId/key, miss shape) — not a coincidental unrelated response.
    await expect
      .poll(async () => {
        const hits = await receivedMessages(frame, CapiType.GET_DATA_RESPONSE);
        return hits.some(
          (m) =>
            m.values?.simId === 'miniFeeder' &&
            m.values?.key === 'progress' &&
            m.values?.exists === false,
        );
      }, { timeout: 15_000 })
      .toBe(true);
  });
});
