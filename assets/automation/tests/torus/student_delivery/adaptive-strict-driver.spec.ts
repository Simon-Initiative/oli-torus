import { Page, Route, expect, test } from '@playwright/test';
import { AdaptiveEvaluationObserver } from '@tasks/AdaptiveEvaluationObserver';
import {
  EvaluationRecord,
  ExpectedSubmission,
  LedgerEntry,
  assertLedger,
  deriveTransition,
  extractSubmittedPairs,
  missingExpectedPaths,
  resolveManifestScreen,
  validateManifest,
  verifyScreenEvaluation,
} from '@tasks/AdaptiveStrictContract';

/**
 * MER-5674: negative tests for the strict adaptive driver's contract and
 * evaluation observer. Stubbed — no Torus server, no credentials: the page
 * is a routed fake origin and every evaluation response is fabricated.
 */

const GUID = 'attempt-guid-current';
const ORIGIN = 'https://adaptive-stub.local';

const PART = {
  attemptGuid: 'part-guid-1',
  response: {
    input: { selectedItem: { path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' } },
  },
};
const EXPECTED: ExpectedSubmission = [{ path: 'stage.dropdown.selectedItem', value: 'Basalt' }];

const CORRECT_BODY = {
  actions: {
    correct: true,
    score: 1,
    out_of: 1,
    results: [{ params: { actions: [{ type: 'navigation', params: { target: 'next' } }] } }],
  },
};

function gradedScreen(over: Record<string, unknown> = {}) {
  return {
    id: 'q:1',
    resource_id: 101,
    role: 'graded',
    answers: [{ kind: 'text_input', value: 'basalt' }],
    ...over,
  };
}

function record(over: Partial<EvaluationRecord> = {}): EvaluationRecord {
  return {
    attemptGuid: GUID,
    screenId: 'q:1',
    otherScreenIds: [],
    llmFeedback: null,
    kind: 'evaluation',
    url: `${ORIGIN}/state/course/s1/activity_attempt/${GUID}`,
    partInputs: [PART],
    requestAt: 1,
    responseAt: 2,
    requestSeq: 1,
    responseSeq: 2,
    status: 200,
    actions: CORRECT_BODY.actions,
    correct: true,
    parseError: null,
    parsed: true,
    ...over,
  };
}

async function bootStub(page: Page, onEvaluation: (route: Route) => Promise<void> | void) {
  await page.route(`${ORIGIN}/**`, async (route) => {
    if (route.request().method() === 'GET') {
      return route.fulfill({ status: 200, contentType: 'text/html', body: '<html></html>' });
    }
    return onEvaluation(route);
  });
  await page.goto(`${ORIGIN}/`);
}

function fireEvaluation(page: Page, guid: string, body: unknown = { partInputs: [PART] }) {
  return page.evaluate(
    async (args) => {
      const res = await fetch(`/state/course/s1/activity_attempt/${args.guid}`, {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(args.body),
      });
      return res.status;
    },
    { guid, body },
  );
}

test.describe('strict manifest validation', () => {
  test('accepts a legal manifest and resolves screens by identity', () => {
    const screens = validateManifest([
      gradedScreen(),
      { id: 'c:2', resource_id: 102, role: 'content' },
      {
        id: 'n:3',
        resource_id: 103,
        role: 'navigation',
        action: { kind: 'in_widget_button', src_fragment: 'nav-widget.html' },
      },
    ]);
    expect(screens).toHaveLength(3);

    const hit = resolveManifestScreen(screens, { id: 'q:1', resourceId: 101, attemptGuid: 'g' });
    expect(hit.role).toBe('graded');
  });

  test('rejects a missing or empty manifest', () => {
    expect(() => validateManifest(undefined)).toThrow(/non-empty array/);
    expect(() => validateManifest([])).toThrow(/non-empty array/);
  });

  test('rejects duplicate screen ids', () => {
    expect(() => validateManifest([gradedScreen(), gradedScreen({ resource_id: 999 })])).toThrow(
      /duplicate screen id "q:1"/,
    );
  });

  test('rejects a graded screen without answers', () => {
    expect(() => validateManifest([gradedScreen({ answers: undefined })])).toThrow(
      /graded and must declare/,
    );
    expect(() => validateManifest([gradedScreen({ answers: [] })])).toThrow(
      /graded and must declare/,
    );
  });

  test('rejects answers on non-graded screens', () => {
    expect(() => validateManifest([gradedScreen({ role: 'content' })])).toThrow(
      /content and must not declare answers/,
    );
  });

  test('rejects a navigation screen without an in-widget action', () => {
    expect(() => validateManifest([{ id: 'n:1', resource_id: 1, role: 'navigation' }])).toThrow(
      /must declare an in_widget_button action/,
    );
  });

  test('rejects unknown roles and directive kinds, and mistyped directives', () => {
    expect(() => validateManifest([gradedScreen({ role: 'bonus' })])).toThrow(/role must be one/);
    expect(() => validateManifest([gradedScreen({ answers: [{ kind: 'telepathy' }] })])).toThrow(
      /unknown kind "telepathy"/,
    );
    expect(() =>
      validateManifest([gradedScreen({ answers: [{ kind: 'ordering', src_fragment: 'x' }] })]),
    ).toThrow(/missing or mistypes/);
  });

  test('rejects an undeclared live screen; live resource ids do not need to match the archive', () => {
    const screens = validateManifest([gradedScreen()]);
    expect(() =>
      resolveManifestScreen(screens, { id: 'ghost', resourceId: 7, attemptGuid: 'g' }),
    ).toThrow(/undeclared screen "ghost"/);
    // imports remap activity ids: a live resourceId differing from the
    // archive's is normal and must resolve
    expect(
      resolveManifestScreen(screens, { id: 'q:1', resourceId: 999, attemptGuid: 'g' }).id,
    ).toBe('q:1');
  });
});

test.describe('submitted payload correlation', () => {
  test('extracts part path/value pairs from partInputs', () => {
    expect(extractSubmittedPairs([PART])).toEqual([
      { path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' },
    ]);
    expect(extractSubmittedPairs(null)).toEqual([]);
    expect(extractSubmittedPairs([{ attemptGuid: 'x', response: { input: null } }])).toEqual([]);
  });

  test('extracts pairs from the deferred-save shape, where response inlines the map', () => {
    expect(
      extractSubmittedPairs([
        {
          attemptGuid: 'x',
          response: {
            selectedIndex: {
              key: 'selectedIndex',
              path: 'q:1|stage.Recap.Selected Index',
              value: 3,
            },
          },
        },
      ]),
    ).toEqual([{ path: 'q:1|stage.Recap.Selected Index', value: 3 }]);
  });

  test('matches expected parts by path suffix, ignoring dynamic prefixes', () => {
    const pairs = extractSubmittedPairs([PART]);
    expect(missingExpectedPaths(pairs, EXPECTED)).toEqual([]);
    expect(
      missingExpectedPaths(pairs, [{ path: 'stage.dropdown.selectedItem', value: 'Granite' }]),
    ).toEqual(['stage.dropdown.selectedItem']);
    expect(missingExpectedPaths([], EXPECTED)).toEqual(['stage.dropdown.selectedItem']);
  });
});

test.describe('per-screen evaluation verdicts', () => {
  const verify = (records: EvaluationRecord[], expected?: ExpectedSubmission) => () =>
    verifyScreenEvaluation({ screenId: 'q:1', records, expected, attemptGuid: GUID });

  test('passes on exactly one correct, payload-matched evaluation', () => {
    expect(verify([record()], EXPECTED)).not.toThrow();
  });

  test('fails without any evaluation', () => {
    expect(verify([])).toThrow(/no evaluation request observed/);
  });

  test('fails on a duplicate evaluation', () => {
    expect(verify([record(), record()])).toThrow(/2 evaluation requests observed/);
  });

  test('fails on a wrong attempt guid', () => {
    expect(verify([record({ attemptGuid: 'attempt-guid-other' })])).toThrow(
      /belongs to attempt attempt-guid-other/,
    );
  });

  test('fails without a response or on a non-2xx response', () => {
    expect(verify([record({ responseAt: null })])).toThrow(/received no response/);
    expect(verify([record({ status: 403 })])).toThrow(/status 403/);
  });

  test('fails on a false, missing, or non-boolean server verdict', () => {
    expect(verify([record({ correct: false })])).toThrow(/correct=false/);
    expect(
      verify([
        record({
          correct: null,
          parseError: 'evaluation response carries no boolean actions.correct',
        }),
      ]),
    ).toThrow(/no boolean actions.correct/);
  });

  test('fails on empty submitted inputs', () => {
    expect(verify([record({ partInputs: [] })])).toThrow(/no part responses/);
  });

  test('fails on a mismatched payload without leaking the answer value', () => {
    const mismatched = verify(
      [record()],
      [{ path: 'stage.dropdown.selectedItem', value: 'Granite' }],
    );
    let message = '';
    try {
      mismatched();
    } catch (e) {
      message = (e as Error).message;
    }
    expect(message).toContain('missing expected parts: stage.dropdown.selectedItem');
    expect(message).not.toContain('Granite');
    expect(message).not.toContain('Basalt');
  });
});

test.describe('transition derivation from response actions', () => {
  test('mirrors the footer branching', () => {
    const withActions = (actions: Array<{ type: string; params?: Record<string, unknown> }>) => ({
      correct: true,
      results: [{ params: { actions } }],
    });

    expect(
      deriveTransition(withActions([{ type: 'navigation', params: { target: 'next' } }])),
    ).toEqual({ kind: 'auto-navigate', target: 'next' });
    expect(
      deriveTransition(withActions([{ type: 'navigation', params: { target: 'endOfLesson' } }])),
    ).toEqual({ kind: 'terminal' });
    expect(
      deriveTransition(
        withActions([
          { type: 'feedback', params: { feedback: {} } },
          { type: 'navigation', params: { target: 'q:2' } },
        ]),
      ),
    ).toEqual({ kind: 'feedback', ack: { kind: 'navigate', target: 'q:2' } });
    expect(deriveTransition(withActions([{ type: 'feedback', params: { feedback: {} } }]))).toEqual(
      {
        kind: 'feedback',
        ack: { kind: 'recheck' },
      },
    );
    expect(deriveTransition(withActions([{ type: 'mutateState' }]))).toEqual({ kind: 'none' });
    expect(deriveTransition({ correct: true }, { text: 'llm feedback' })).toEqual({
      kind: 'feedback',
      ack: { kind: 'recheck' },
    });
  });
});

test.describe('evaluation observer against a stubbed page', () => {
  const SCREEN = 'q:1';

  test('captures the submission, verdict, and payload of one evaluation', async ({ page }) => {
    await bootStub(page, (route) => route.fulfill({ status: 200, json: CORRECT_BODY }));
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID);
      const evaluation = await observer.waitForEvaluation(1, 5_000);

      expect(evaluation.status).toBe(200);
      expect(evaluation.correct).toBe(true);
      expect(evaluation.kind).toBe('evaluation');
      expect(evaluation.screenId).toBe(SCREEN);
      expect(extractSubmittedPairs(evaluation.partInputs)).toEqual([
        { path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' },
      ]);
      expect(() =>
        verifyScreenEvaluation({
          screenId: SCREEN,
          records: observer.evaluations(),
          expected: EXPECTED,
          attemptGuid: GUID,
        }),
      ).not.toThrow();
    } finally {
      observer.dispose();
    }
  });

  test('records a duplicate submission arriving after the first response', async ({ page }) => {
    await bootStub(page, (route) => route.fulfill({ status: 200, json: CORRECT_BODY }));
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID);
      await observer.waitForEvaluation(1, 5_000);
      await fireEvaluation(page, GUID);

      await expect.poll(() => observer.evaluations().length, { timeout: 5_000 }).toBe(2);
      expect(() =>
        verifyScreenEvaluation({ screenId: SCREEN, records: observer.evaluations() }),
      ).toThrow(/2 evaluation requests observed/);
    } finally {
      observer.dispose();
    }
  });

  test('attributes evaluations across rotating attempt guids to this screen', async ({ page }) => {
    // the deck rotates the attempt after an incorrect non-navigating check
    // with attempts remaining (triggerCheck.ts:424), so one screen's
    // evaluations can legally span several guids
    await bootStub(page, (route) => route.fulfill({ status: 200, json: CORRECT_BODY }));
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, 'attempt-guid-first');
      await fireEvaluation(page, 'attempt-guid-second');

      await expect.poll(() => observer.evaluations().length, { timeout: 5_000 }).toBe(2);
      expect(observer.foreignEvaluations()).toHaveLength(0);
    } finally {
      observer.dispose();
    }
  });

  test('settle() blocks on an unparsed mint and exposes the minted guid once it lands', async ({
    page,
  }) => {
    let heldMint: Route | null = null;
    await bootStub(page, (route) => {
      if (route.request().method() === 'POST') {
        heldMint = route;
        return;
      }
      return route.fulfill({ status: 200, json: CORRECT_BODY });
    });
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await page.evaluate(async (guid) => {
        void fetch(`/state/course/s1/activity_attempt/${guid}`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ seedResponsesWithPrevious: true }),
        });
      }, GUID);
      await expect.poll(() => observer.creations().length, { timeout: 5_000 }).toBe(1);
      await expect.poll(() => heldMint !== null, { timeout: 5_000 }).toBe(true);

      expect(await observer.settle(500)).toBe(false);
      expect(observer.creations()[0].parsed).toBe(false);

      await heldMint!.fulfill({
        status: 200,
        json: { attemptState: { attemptGuid: 'minted-guid' } },
      });
      expect(await observer.settle(5_000)).toBe(true);
      expect(observer.creations()[0]).toMatchObject({
        targetGuid: GUID,
        newGuid: 'minted-guid',
        status: 200,
        parsed: true,
      });
    } finally {
      observer.dispose();
    }
  });

  test('preserves the other prefixes of a mixed submission for contamination checks', async ({
    page,
  }) => {
    await bootStub(page, (route) => route.fulfill({ status: 200, json: CORRECT_BODY }));
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID, {
        partInputs: [
          PART,
          {
            attemptGuid: 'part-guid-8',
            response: {
              input: { stray: { path: 'q:9|stage.other.value', value: 'stale' } },
            },
          },
        ],
      });
      const evaluation = await observer.waitForEvaluation(1, 5_000);

      expect(evaluation.screenId).toBe(SCREEN);
      expect(evaluation.otherScreenIds).toEqual(['q:9']);
    } finally {
      observer.dispose();
    }
  });

  test("never attributes another screen's submission to this one", async ({ page }) => {
    await bootStub(page, (route) => route.fulfill({ status: 200, json: CORRECT_BODY }));
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID, {
        partInputs: [
          {
            attemptGuid: 'part-guid-9',
            response: {
              input: { late: { path: 'q:0|stage.iframe.value', value: 'stale' } },
            },
          },
        ],
      });

      await expect.poll(() => observer.foreignEvaluations().length, { timeout: 5_000 }).toBe(1);
      expect(observer.evaluations()).toHaveLength(0);
      expect(observer.foreignEvaluations()[0].screenId).toBe('q:0');
      await expect(observer.waitForEvaluation(1, 400)).rejects.toThrow(
        /no evaluation 1 for screen q:1.*foreign: 1/,
      );
    } finally {
      observer.dispose();
    }
  });

  test('classifies a finalize save separately from evaluations', async ({ page }) => {
    await bootStub(page, (route) => route.fulfill({ status: 200, json: { type: 'success' } }));
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID);
      await expect(observer.waitForEvaluation(1, 1_000)).rejects.toThrow(/no evaluation 1/);
      expect(observer.evaluations()).toHaveLength(0);
      expect(observer.foreignEvaluations()).toHaveLength(0);
    } finally {
      observer.dispose();
    }
  });

  test('marks a malformed response body unusable', async ({ page }) => {
    await bootStub(page, (route) =>
      route.fulfill({ status: 200, contentType: 'application/json', body: 'not json at all' }),
    );
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID);
      const evaluation = await observer.waitForEvaluation(1, 5_000);

      expect(evaluation.parseError).toMatch(/unreadable evaluation response/);
      expect(() =>
        verifyScreenEvaluation({ screenId: SCREEN, records: observer.evaluations() }),
      ).toThrow(/evaluation unusable/);
    } finally {
      observer.dispose();
    }
  });

  test('marks a non-boolean verdict unusable', async ({ page }) => {
    await bootStub(page, (route) =>
      route.fulfill({ status: 200, json: { actions: { correct: 'yes' } } }),
    );
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID);
      const evaluation = await observer.waitForEvaluation(1, 5_000);

      expect(evaluation.correct).toBeNull();
      expect(() =>
        verifyScreenEvaluation({ screenId: SCREEN, records: observer.evaluations() }),
      ).toThrow(/no boolean actions.correct/);
    } finally {
      observer.dispose();
    }
  });

  test('records a failed evaluation as a failure, not as missing feedback', async ({ page }) => {
    await bootStub(page, (route) =>
      route.fulfill({ status: 403, json: { error: 'already_submitted' } }),
    );
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await fireEvaluation(page, GUID);
      const evaluation = await observer.waitForEvaluation(1, 5_000);

      expect(evaluation.status).toBe(403);
      expect(() =>
        verifyScreenEvaluation({ screenId: SCREEN, records: observer.evaluations() }),
      ).toThrow(/status 403/);
    } finally {
      observer.dispose();
    }
  });

  test('times out loudly when no evaluation request appears', async ({ page }) => {
    await bootStub(page, (route) => route.fulfill({ status: 200, json: CORRECT_BODY }));
    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    try {
      await expect(observer.waitForEvaluation(1, 300)).rejects.toThrow(
        /no evaluation 1 for screen q:1 within 300ms \(own: 0, foreign: 0\)/,
      );
    } finally {
      observer.dispose();
    }
  });

  test('detaches its listeners on dispose and refuses double arming', async ({ page }) => {
    await bootStub(page, (route) => route.fulfill({ status: 200, json: CORRECT_BODY }));
    const emitter = page as unknown as NodeJS.EventEmitter;
    const before = emitter.listenerCount('request');

    const observer = new AdaptiveEvaluationObserver(page, SCREEN);
    observer.arm();
    expect(emitter.listenerCount('request')).toBe(before + 1);
    expect(() => observer.arm()).toThrow(/already armed/);

    observer.dispose();
    expect(emitter.listenerCount('request')).toBe(before);

    await fireEvaluation(page, GUID);
    await new Promise((resolve) => setTimeout(resolve, 200));
    expect(observer.evaluations()).toHaveLength(0);
  });
});

test.describe('expected-part matching variants', () => {
  const pairs = extractSubmittedPairs([
    PART,
    {
      attemptGuid: 'part-guid-2',
      response: {
        input: {
          selectedChoiceText: {
            path: 'q:1|stage.mcq1.selectedChoiceText',
            value: 'The soup is moving without any stirring',
          },
          simState: { path: 'q:1|stage.frame7.Blank1', value: 'upward' },
        },
      },
    },
  ]);

  test('value_matches tests a regex over the stringified value', () => {
    expect(
      missingExpectedPaths(pairs, [
        { path: 'stage.mcq1.selectedChoiceText', value_matches: 'moving without any stirring' },
      ]),
    ).toEqual([]);
    expect(
      missingExpectedPaths(pairs, [
        { path: 'stage.mcq1.selectedChoiceText', value_matches: 'perfectly still' },
      ]),
    ).toEqual(['stage.mcq1.selectedChoiceText']);
  });

  test('path_prefix asserts presence of a widget state cluster', () => {
    expect(missingExpectedPaths(pairs, [{ path_prefix: 'stage.frame7.' }])).toEqual([]);
    expect(missingExpectedPaths(pairs, [{ path_prefix: 'stage.frame9.' }])).toEqual([
      'stage.frame9.*',
    ]);
  });

  test('a prefix expectation can also require a value under that cluster', () => {
    expect(
      missingExpectedPaths(pairs, [{ path_prefix: 'stage.frame7.', value_matches: 'upward' }]),
    ).toEqual([]);
    // present cluster, wrong value — must NOT satisfy
    expect(
      missingExpectedPaths(pairs, [{ path_prefix: 'stage.frame7.', value_matches: 'downward' }]),
    ).toEqual(['stage.frame7.*']);
  });
});

test.describe('ledger invariants', () => {
  const MANIFEST = validateManifest([
    {
      id: 'n:0',
      resource_id: 100,
      role: 'navigation',
      action: { kind: 'in_widget_button', src_fragment: 'button-widget' },
    },
    { id: 'c:1', resource_id: 101, role: 'content' },
    gradedScreen({ id: 'q:2', resource_id: 102 }),
    { id: 'c:3', resource_id: 103, role: 'content' },
  ]);

  const receipt = (screenId: string) => ({
    screenId,
    directive: 'text_input' as const,
    readback: 'redacted',
    expected: [],
  });

  const entry = (over: Partial<LedgerEntry> & { screenId: string }): LedgerEntry => {
    const declared = MANIFEST.find((s) => s.id === over.screenId);
    const role = over.role ?? declared?.role ?? 'content';
    return {
      resourceId: declared?.resource_id ?? 0,
      attemptGuid: `guid-${over.screenId}`,
      role,
      receipt: role === 'graded' ? receipt(over.screenId) : null,
      evaluationCount: role === 'navigation' ? 0 : 1,
      expectedEvaluations: role === 'navigation' ? undefined : 1,
      verdict: role === 'graded' ? true : null,
      payloadMatch: role === 'graded' ? true : null,
      transition: { kind: 'auto-navigate', target: 'next' },
      ...over,
    };
  };

  const fullWalk = (): LedgerEntry[] => [
    entry({ screenId: 'n:0', transition: null }),
    entry({ screenId: 'c:1' }),
    entry({ screenId: 'q:2' }),
    entry({ screenId: 'c:3', transition: { kind: 'terminal' } }),
  ];

  test('passes a complete, ordered, correct walk', () => {
    expect(() => assertLedger(fullWalk(), MANIFEST)).not.toThrow();
  });

  test('fails on skipped, repeated, or out-of-order screens', () => {
    const skipped = fullWalk().filter((e) => e.screenId !== 'q:2');
    expect(() => assertLedger(skipped, MANIFEST)).toThrow(/visited 3 screens.*declares 4/);

    const repeated = fullWalk();
    repeated[1] = entry({ screenId: 'q:2' });
    expect(() => assertLedger(repeated, MANIFEST)).toThrow(
      /position 1 visited "q:2", manifest declares "c:1"/,
    );
  });

  test('fails on a graded screen without evaluation, receipt, verdict, or payload match', () => {
    const noEval = fullWalk();
    noEval[2] = entry({ screenId: 'q:2', evaluationCount: 0 });
    expect(() => assertLedger(noEval, MANIFEST)).toThrow(
      /saw 0 evaluation\(s\), the walk licensed exactly 1/,
    );

    // an accidental extra submission cannot hide inside a role range: the
    // walk licenses an exact count (2 only on a legal feedback re-check)
    const strayDuplicate = fullWalk();
    strayDuplicate[2] = entry({ screenId: 'q:2', evaluationCount: 2 });
    expect(() => assertLedger(strayDuplicate, MANIFEST)).toThrow(
      /saw 2 evaluation\(s\), the walk licensed exactly 1/,
    );

    const legalRecheck = fullWalk();
    legalRecheck[2] = entry({ screenId: 'q:2', evaluationCount: 2, expectedEvaluations: 2 });
    expect(() => assertLedger(legalRecheck, MANIFEST)).not.toThrow();

    // fail closed: a submitting screen with no recorded licence never falls
    // back to the permissive role range
    const unlicensed = fullWalk();
    unlicensed[2] = entry({ screenId: 'q:2', evaluationCount: 2, expectedEvaluations: undefined });
    expect(() => assertLedger(unlicensed, MANIFEST)).toThrow(
      /recorded no licensed evaluation count/,
    );

    const noReceipt = fullWalk();
    noReceipt[2] = entry({ screenId: 'q:2', receipt: null });
    expect(() => assertLedger(noReceipt, MANIFEST)).toThrow(/has no answer receipt/);

    const wrongVerdict = fullWalk();
    wrongVerdict[2] = entry({ screenId: 'q:2', verdict: false });
    expect(() => assertLedger(wrongVerdict, MANIFEST)).toThrow(/verdict=false/);

    const noMatch = fullWalk();
    noMatch[2] = entry({ screenId: 'q:2', payloadMatch: false });
    expect(() => assertLedger(noMatch, MANIFEST)).toThrow(/payloadMatch=false/);
  });

  test('tolerates up to two navigation-screen evaluations, fails beyond', () => {
    // a navigation widget's own check can evaluate wrong-then-right across a
    // fresh attempt (observed on the LotE cover) — two are legal, three are not
    const twoEvals = fullWalk();
    twoEvals[0] = entry({ screenId: 'n:0', evaluationCount: 2, transition: null });
    expect(() => assertLedger(twoEvals, MANIFEST)).not.toThrow();

    const threeEvals = fullWalk();
    threeEvals[0] = entry({ screenId: 'n:0', evaluationCount: 3, transition: null });
    expect(() => assertLedger(threeEvals, MANIFEST)).toThrow(
      /\(navigation\) saw 3 evaluation\(s\), expected 0-2/,
    );
  });

  test('fails on premature or missing terminal transition', () => {
    const premature = fullWalk();
    premature[1] = entry({ screenId: 'c:1', transition: { kind: 'terminal' } });
    expect(() => assertLedger(premature, MANIFEST)).toThrow(
      /position 1 is terminal before the last screen/,
    );

    // a lesson may also end by auto-navigating off its last screen
    const autoNavEnd = fullWalk();
    autoNavEnd[3] = entry({
      screenId: 'c:3',
      transition: { kind: 'auto-navigate', target: 'next' },
    });
    expect(() => assertLedger(autoNavEnd, MANIFEST)).not.toThrow();

    const unfinished = fullWalk();
    unfinished[3] = entry({ screenId: 'c:3', transition: { kind: 'none' } });
    expect(() => assertLedger(unfinished, MANIFEST)).toThrow(
      /ended on none, expected terminal or auto-navigate/,
    );
  });

  test('ledger failure output is redacted to identities and counts', () => {
    const wrongVerdict = fullWalk();
    wrongVerdict[2] = entry({ screenId: 'q:2', verdict: false });
    let message = '';
    try {
      assertLedger(wrongVerdict, MANIFEST);
    } catch (e) {
      message = (e as Error).message;
    }
    expect(message).toContain('q:2 role=graded evals=1 verdict=false');
    expect(message).not.toContain('basalt');
  });
});
