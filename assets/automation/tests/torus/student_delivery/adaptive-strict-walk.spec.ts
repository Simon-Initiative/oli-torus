import { Page, Route, expect, test } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import { completeAdaptiveHappyPathStrict } from '@tasks/AdaptiveHappyPathTask';

/**
 * MER-5674: orchestration tests for the strict walk itself. The observer and
 * contract helpers are covered in adaptive-strict-driver.spec.ts; this file
 * drives completeAdaptiveHappyPathStrict against a scripted fake deck so the
 * escapes that only exist BETWEEN those pieces — attempt-guid correlation per
 * role, licensing of a second submission, traffic arriving after the
 * transition boundary — are exercised.
 *
 * The page is a routed fake origin; the fake deck issues real PUTs from it,
 * so the walk's own observer sees genuine request/response traffic.
 */

const ORIGIN = 'https://adaptive-walk-stub.local';

type ScriptedScreen = {
  id: string;
  role: 'graded' | 'content' | 'navigation';
  attemptGuid: string;
  /** guid the submission is made under, when it must differ from the rendered one */
  submitGuid?: string;
  answers?: Array<Record<string, unknown>>;
  parts?: Array<{ id: string; type: string; src: string | null }>;
  /** evaluation bodies this screen returns, in order */
  responses: unknown[];
  /** extra submissions fired after the screen's transition completed */
  lateSubmissions?: Array<{
    guid: string;
    body: unknown;
    screenId: string;
    /** POST simulates the deck minting a fresh attempt (rotation) */
    method?: 'PUT' | 'POST';
    /** response status override — e.g. a failing mint */
    responseStatus?: number;
    /** request payload override — e.g. a malformed body with no partInputs */
    payload?: unknown;
    /** hold this request's RESPONSE until the named guid's request arrives */
    holdUntil?: string;
    /** batches fire in ascending order, each awaited before the next starts */
    batch?: number;
  }>;
};

const navAction = { kind: 'in_widget_button', src_fragment: 'button-widget' };

type LateItem = {
  guid: string;
  response: unknown;
  method: string;
  status: number;
  payload: unknown;
  holdUntil: string | null;
  batch: number;
};

const answeredBody = (target = 'next') => ({
  actions: {
    correct: true,
    results: [{ params: { actions: [{ type: 'navigation', params: { target } }] } }],
  },
});

const wrongNonNavigatingBody = () => ({
  actions: { correct: false, results: [{ params: { actions: [] } }] },
});

const feedbackRecheckBody = () => ({
  actions: {
    correct: true,
    results: [{ params: { actions: [{ type: 'feedback', params: { feedback: {} } }] } }],
  },
});

const textPart = (id: string) => ({ id, type: 'janus-multi-line-text', src: null });

const textInput = (value: string) => ({ kind: 'text_input', value });

function submissionFor(screenId: string, partId: string, value: string) {
  return {
    partInputs: [
      {
        attemptGuid: `part-${screenId}`,
        response: { input: { text: { path: `${screenId}|stage.${partId}.text`, value } } },
      },
    ],
  };
}

/**
 * A deck whose every method is scripted. It fires real PUTs so the walk's
 * observer records genuine traffic, and it advances only when the walk drives
 * it, so ordering bugs surface as failures rather than hangs.
 */
class FakeDeck {
  index = 0;
  private responseCursor = 0;
  private feedbackOpen = false;

  constructor(
    private readonly page: Page,
    private readonly script: ScriptedScreen[],
  ) {}

  private get current(): ScriptedScreen {
    return this.script[Math.min(this.index, this.script.length - 1)];
  }

  private async submit(): Promise<void> {
    const screen = this.current;
    const body = screen.responses[this.responseCursor] ?? answeredBody();
    const partId = screen.parts?.[0]?.id ?? 'input1';
    await this.page.evaluate(
      async (args) => {
        (window as unknown as { __next?: unknown }).__next = args.response;
        await fetch(`/state/course/s1/activity_attempt/${args.guid}`, {
          method: 'PUT',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify(args.payload),
        });
      },
      {
        guid: screen.submitGuid ?? screen.attemptGuid,
        response: body,
        payload: submissionFor(screen.id, partId, 'an answer'),
      },
    );
    this.responseCursor += 1;
  }

  private async fireLate(): Promise<void> {
    const lates = this.current.lateSubmissions ?? [];
    if (lates.length === 0) return;
    const items = lates.map((late) => ({
      guid: late.guid,
      response: late.body,
      method: late.method ?? 'PUT',
      status: late.responseStatus ?? 200,
      payload: late.payload ?? submissionFor(late.screenId, 'input1', 'late'),
      holdUntil: late.holdUntil ?? null,
      batch: late.batch ?? 0,
    }));
    const batches = new Map<number, LateItem[]>();
    for (const item of items) {
      batches.set(item.batch, [...(batches.get(item.batch) ?? []), item]);
    }
    for (const key of Array.from(batches.keys()).sort((a, b) => a - b)) {
      await this.fireBatch(batches.get(key)!);
    }
  }

  private async fireBatch(items: LateItem[]): Promise<void> {
    const concurrent = items.some((it) => it.holdUntil);
    // when any item in the batch holds, the batch fires in flight together: a
    // held request's response is released only when the named guid's request
    // arrives
    await this.page.evaluate(
      async (args) => {
        const send = (it: {
          guid: string;
          response: unknown;
          method: string;
          status: number;
          payload: unknown;
          holdUntil: string | null;
        }) =>
          fetch(`/state/course/s1/activity_attempt/${it.guid}`, {
            method: it.method,
            headers: {
              'content-type': 'application/json',
              'x-stub-response': JSON.stringify(it.response),
              'x-stub-status': String(it.status),
              ...(it.holdUntil ? { 'x-stub-hold-until': it.holdUntil } : {}),
            },
            body: JSON.stringify(it.payload),
          });
        if (args.concurrent) {
          await Promise.all(args.items.map((it) => send(it)));
        } else {
          for (const it of args.items) await send(it);
        }
      },
      { items, concurrent },
    );
  }

  async waitForDeckReady(): Promise<void> {}

  async lessonEnded(): Promise<boolean> {
    return this.index >= this.script.length;
  }

  async readScreenIdentity() {
    const s = this.current;
    return { id: s.id, resourceId: 100 + this.index, attemptGuid: s.attemptGuid };
  }

  async readPartInventory() {
    return this.current.parts ?? [textPart('input1')];
  }

  async playVideos(): Promise<number> {
    return 0;
  }

  async clickThroughCarousels(): Promise<number> {
    return 0;
  }

  async fillTextInputs(): Promise<number> {
    return 1;
  }

  async submitCheck(): Promise<void> {
    await this.submit();
    this.feedbackOpen = true;
  }

  async clickWidgetButton(): Promise<boolean> {
    if (this.current.responses.length > 0) await this.submit();
    return true;
  }

  async waitForFeedbackOpen(): Promise<void> {
    if (!this.feedbackOpen) throw new Error('feedback popup did not open');
  }

  async acknowledgeFeedback(): Promise<void> {
    this.feedbackOpen = false;
    await this.submit();
  }

  async waitForScreenChange(): Promise<void> {
    await this.fireLate();
    this.index += 1;
    this.responseCursor = 0;
    this.feedbackOpen = false;
  }

  async waitForLessonEnd(): Promise<void> {
    await this.fireLate();
    this.index = this.script.length;
  }
}

async function walk(page: Page, script: ScriptedScreen[]) {
  const held = new Map<string, Array<{ route: Route; json: object; status: number }>>();
  await page.route(`${ORIGIN}/**`, async (route) => {
    const request = route.request();
    if (request.method() === 'GET') {
      return route.fulfill({ status: 200, contentType: 'text/html', body: '<html></html>' });
    }
    const headerBody = request.headers()['x-stub-response'];
    const json = headerBody
      ? (JSON.parse(headerBody) as object)
      : (((await page.evaluate(() => (window as unknown as { __next?: unknown }).__next)) ??
          answeredBody()) as object);
    const status = Number(request.headers()['x-stub-status'] ?? 200);
    const guid = /activity_attempt\/([^/?#]+)/.exec(request.url())?.[1] ?? '';
    const releasable = held.get(guid);
    if (releasable) {
      held.delete(guid);
      // the released response must land strictly after this request
      await new Promise((resolve) => setTimeout(resolve, 10));
      for (const h of releasable) await h.route.fulfill({ status: h.status, json: h.json });
    }
    const holdUntil = request.headers()['x-stub-hold-until'];
    if (holdUntil) {
      held.set(holdUntil, [...(held.get(holdUntil) ?? []), { route, json, status }]);
      return;
    }
    return route.fulfill({ status, json });
  });
  await page.goto(`${ORIGIN}/`);

  const deck = new FakeDeck(page, script);
  const screens = script.map((s) => ({
    id: s.id,
    resource_id: 1,
    role: s.role,
    ...(s.role === 'graded' ? { answers: s.answers ?? [textInput('an answer')] } : {}),
    ...(s.role === 'navigation' ? { action: navAction } : {}),
  }));

  return completeAdaptiveHappyPathStrict(page, deck as unknown as AdaptiveDeckPO, {
    lesson: {},
    screens,
  });
}

test.describe('strict walk orchestration', () => {
  test('passes a clean two-screen walk and records one licensed evaluation each', async ({
    page,
  }) => {
    const ledger = await walk(page, [
      { id: 'q:1', role: 'graded', attemptGuid: 'g1', responses: [answeredBody()] },
      { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
    ]);

    expect(ledger).toHaveLength(2);
    expect(ledger[0]).toMatchObject({ evaluationCount: 1, expectedEvaluations: 1, verdict: true });
    expect(ledger[1]).toMatchObject({ evaluationCount: 1, expectedEvaluations: 1 });
  });

  test('fails when a graded screen submits under a different attempt than it rendered', async ({
    page,
  }) => {
    await expect(
      walk(page, [
        {
          id: 'q:1',
          role: 'graded',
          attemptGuid: 'rendered-guid',
          submitGuid: 'stale-guid',
          responses: [answeredBody('endOfLesson')],
        },
      ]),
    ).rejects.toThrow(/evaluation used attempt stale-guid, the screen rendered attempt/);
  });

  test('fails when a CONTENT screen submits under a stale attempt', async ({ page }) => {
    await expect(
      walk(page, [
        {
          id: 'c:1',
          role: 'content',
          attemptGuid: 'rendered-guid',
          submitGuid: 'stale-guid',
          responses: [answeredBody('endOfLesson')],
        },
      ]),
    ).rejects.toThrow(/\(content\): evaluation used attempt stale-guid/);
  });

  test('tolerates a navigation screen submitting under a rotated attempt', async ({ page }) => {
    // the Cover widget can check during init, rotating the attempt before the
    // walk clicks — measured on LotE, so the rendered guid is not the anchor
    const ledger = await walk(page, [
      {
        id: 'n:1',
        role: 'navigation',
        attemptGuid: 'rendered-guid',
        submitGuid: 'rotated-guid',
        responses: [answeredBody()],
      },
      { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
    ]);
    expect(ledger[0]).toMatchObject({ role: 'navigation', evaluationCount: 1 });
  });

  test('licenses the measured navigation rotation: wrong non-navigating, then right on a fresh attempt', async ({
    page,
  }) => {
    // an incorrect check with no navigation rotates the attempt
    // (triggerCheck.ts:424): the deck POSTs to mint a fresh attempt and the
    // second check submits under the minted guid — the Cover was measured
    // doing exactly this
    const ledger = await walk(page, [
      {
        id: 'n:1',
        role: 'navigation',
        attemptGuid: 'g1',
        responses: [wrongNonNavigatingBody()],
        lateSubmissions: [
          {
            guid: 'g1',
            method: 'POST',
            body: { attemptState: { attemptGuid: 'rotated-attempt' } },
            screenId: 'n:1',
          },
          { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
        ],
      },
      { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
    ]);
    expect(ledger[0]).toMatchObject({ role: 'navigation', evaluationCount: 2 });
  });

  test('fails wrong-then-right across attempts when no fresh attempt was minted between them', async ({
    page,
  }) => {
    // the round-7 window: second check starts after the first response but
    // the rotation artifact never happened — without an observed mint whose
    // guid the second check uses, the pair is not the measured rotation
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [{ guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' }],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/licensed only as the measured rotation.*mint=missing/);
  });

  test('fails when the mint produced a different guid than the second check used', async ({
    page,
  }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [
            {
              guid: 'g1',
              method: 'POST',
              body: { attemptState: { attemptGuid: 'some-other-mint' } },
              screenId: 'n:1',
            },
            { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
          ],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/licensed only as the measured rotation.*mint=missing/);
  });

  test("fails when the mint targeted a different attempt than the first check's", async ({
    page,
  }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [
            {
              guid: 'unrelated-attempt',
              method: 'POST',
              body: { attemptState: { attemptGuid: 'rotated-attempt' } },
              screenId: 'n:1',
            },
            { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
          ],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/licensed only as the measured rotation.*mint=missing/);
  });

  test('fails when the mint returned a non-2xx status', async ({ page }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [
            {
              guid: 'g1',
              method: 'POST',
              body: { attemptState: { attemptGuid: 'rotated-attempt' } },
              responseStatus: 500,
              screenId: 'n:1',
            },
            { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
          ],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/licensed only as the measured rotation.*mint=observed/);
  });

  test('fails when the second check starts before the mint response lands', async ({ page }) => {
    // the mint's response is held until the second check's request arrives,
    // so the second check cannot have learned its guid from this mint
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [
            {
              guid: 'g1',
              method: 'POST',
              body: { attemptState: { attemptGuid: 'rotated-attempt' } },
              screenId: 'n:1',
              holdUntil: 'rotated-attempt',
            },
            { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
          ],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/licensed only as the measured rotation.*mint=observed/);
  });

  test('fails when the mint was requested before the first response landed', async ({ page }) => {
    // batch 0: the first check's response is held until the mint's request
    // arrives, so the mint cannot be a reaction to it; batch 1 stages the
    // second check strictly after the mint response, so the mint-after-first
    // guard is the only one violated
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [],
          lateSubmissions: [
            {
              guid: 'g1',
              body: wrongNonNavigatingBody(),
              screenId: 'n:1',
              holdUntil: 'g1',
            },
            {
              guid: 'g1',
              method: 'POST',
              body: { attemptState: { attemptGuid: 'rotated-attempt' } },
              screenId: 'n:1',
            },
            { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1', batch: 1 },
          ],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/licensed only as the measured rotation.*mint=observed/);
  });

  test('licenses the dance among several mints when exactly one chain qualifies', async ({
    page,
  }) => {
    const ledger = await walk(page, [
      {
        id: 'n:1',
        role: 'navigation',
        attemptGuid: 'g1',
        responses: [wrongNonNavigatingBody()],
        lateSubmissions: [
          {
            guid: 'unrelated-attempt',
            method: 'POST',
            body: { attemptState: { attemptGuid: 'noise-mint' } },
            screenId: 'n:1',
          },
          {
            guid: 'g1',
            method: 'POST',
            body: { attemptState: { attemptGuid: 'rotated-attempt' } },
            screenId: 'n:1',
          },
          { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
        ],
      },
      { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
    ]);
    expect(ledger[0]).toMatchObject({ role: 'navigation', evaluationCount: 2 });
  });

  test('fails a navigation duplicate: two correct evaluations across attempts', async ({
    page,
  }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [answeredBody()],
          lateSubmissions: [{ guid: 'other-attempt', body: answeredBody(), screenId: 'n:1' }],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/two evaluations are licensed only as the measured rotation/);
  });

  test('fails the rotation shape when both evaluations share one attempt', async ({ page }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [{ guid: 'g1', body: answeredBody(), screenId: 'n:1' }],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/two evaluations are licensed only as the measured rotation/);
  });

  test('fails when an unusable request occupies a navigation licence slot', async ({ page }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [{ guid: 'rotated-attempt', body: {}, screenId: 'n:1' }],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/unusable evaluation in its licensed range/);
  });

  test('fails overlapping in-flight checks that mimic the rotation shape', async ({ page }) => {
    // both requests are in flight together — the wrong one's response is held
    // until the correct one's request arrives, so no rotation can have
    // happened between them
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [],
          lateSubmissions: [
            {
              guid: 'g1',
              body: wrongNonNavigatingBody(),
              screenId: 'n:1',
              holdUntil: 'rotated-attempt',
            },
            { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
          ],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/licensed only as the measured rotation.*mint=missing/);
  });

  test('fails a malformed request whose response looks like a valid evaluation', async ({
    page,
  }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [],
          lateSubmissions: [{ guid: 'g1', body: answeredBody(), screenId: 'n:1', payload: {} }],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/unusable evaluation in its licensed range/);
  });

  test('fails when a navigation screen exceeds its evaluation licence', async ({ page }) => {
    await expect(
      walk(page, [
        {
          id: 'n:1',
          role: 'navigation',
          attemptGuid: 'g1',
          responses: [wrongNonNavigatingBody()],
          lateSubmissions: [
            { guid: 'rotated-attempt', body: answeredBody(), screenId: 'n:1' },
            { guid: 'third-attempt', body: answeredBody(), screenId: 'n:1' },
          ],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/3 evaluation\(s\) once its transition settled, the licence allows 0-2/);
  });

  test('licenses a second evaluation for a graded feedback re-check', async ({ page }) => {
    const ledger = await walk(page, [
      {
        id: 'q:1',
        role: 'graded',
        attemptGuid: 'g1',
        responses: [feedbackRecheckBody(), answeredBody('endOfLesson')],
      },
    ]);

    expect(ledger[0]).toMatchObject({ evaluationCount: 2, expectedEvaluations: 2, verdict: true });
  });

  test('refuses a second evaluation for a CONTENT screen', async ({ page }) => {
    await expect(
      walk(page, [
        {
          id: 'c:1',
          role: 'content',
          attemptGuid: 'g1',
          responses: [feedbackRecheckBody(), answeredBody('endOfLesson')],
        },
      ]),
    ).rejects.toThrow(/content screen "c:1" re-checked after feedback/);
  });

  test('catches a duplicate submission that lands after the transition boundary', async ({
    page,
  }) => {
    await expect(
      walk(page, [
        {
          id: 'q:1',
          role: 'graded',
          attemptGuid: 'g1',
          responses: [answeredBody('endOfLesson')],
          lateSubmissions: [{ guid: 'g1', body: answeredBody(), screenId: 'q:1' }],
        },
      ]),
    ).rejects.toThrow(/2 evaluation\(s\) once its transition settled, the walk licensed exactly 1/);
  });

  test("catches another manifest screen's traffic arriving after the boundary", async ({
    page,
  }) => {
    await expect(
      walk(page, [
        {
          id: 'q:1',
          role: 'graded',
          attemptGuid: 'g1',
          responses: [answeredBody()],
          lateSubmissions: [{ guid: 'g9', body: answeredBody(), screenId: 'q:9' }],
        },
        { id: 'c:2', role: 'content', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
      ]),
    ).rejects.toThrow(/submission\(s\) for a different screen observed during its transition/);
  });

  test('fails when the walk visits a screen the manifest does not declare next', async ({
    page,
  }) => {
    const script: ScriptedScreen[] = [
      { id: 'q:1', role: 'graded', attemptGuid: 'g1', responses: [answeredBody()] },
      { id: 'q:2', role: 'graded', attemptGuid: 'g2', responses: [answeredBody('endOfLesson')] },
    ];
    // the deck renders them in the wrong order
    const swapped = [script[1], script[0]];
    await expect(
      (async () => {
        await page.route(`${ORIGIN}/**`, async (route) => {
          if (route.request().method() === 'GET') {
            return route.fulfill({ status: 200, contentType: 'text/html', body: '<html></html>' });
          }
          return route.fulfill({ status: 200, json: answeredBody() });
        });
        await page.goto(`${ORIGIN}/`);
        const deck = new FakeDeck(page, swapped);
        return completeAdaptiveHappyPathStrict(page, deck as unknown as AdaptiveDeckPO, {
          lesson: {},
          screens: script.map((s) => ({
            id: s.id,
            resource_id: 1,
            role: s.role,
            answers: [textInput('an answer')],
          })),
        });
      })(),
    ).rejects.toThrow(/position 0 shows "q:2", manifest declares "q:1"/);
  });
});
