import { expect, test } from '@playwright/test';
import { AdaptiveJournalCore, JournalSnapshot } from '@tasks/AdaptiveJournal';
import {
  AdaptiveManifest,
  evaluatePredicate,
  resolveOperations,
  selectedCount,
  validateAdaptiveManifest,
  validateRouteCoverage,
} from '@tasks/AdaptiveManifest';
import {
  RunRecord,
  StepReceipt,
  auditCrossScreenReceipt,
  auditRun,
  committedPriorState,
  formatViolations,
} from '@tasks/AdaptiveOracle';
import { planTransition, selectProcessedEvents } from '@tasks/AdaptiveTransitionPlanner';

/**
 * MER-5865 step 2 (spec §3.4–§3.8, §8): manifest v2 validation by name,
 * predicate matrix (accept + reject per operator, both selectedChoices
 * encodings), the footer-normative combineFeedback planner branches, and the
 * oracle's invariant inventory driven over REAL journal snapshots — the
 * negative classes the 64 v1 stub tests proved for the walker, restated
 * against `auditRun`, plus the new §8 matrices (edge-less evaluation,
 * split-rotation navigation, savedBarrier temporal audit, distinct-path
 * min_count, committed-prior-state lineage, freeze-timeout mapping).
 */

const ORIGIN = 'https://adaptive-stub.local';
const CORR = { sectionSlug: 's-1', revisionSlug: 'r-1', resourceAttemptGuid: 'ra-1' };

// ---------------------------------------------------------------------------
// manifest fixtures
// ---------------------------------------------------------------------------

const MANIFEST: AdaptiveManifest = {
  screens: [
    {
      id: 'n:1',
      resource_id: 101,
      role: 'navigation',
      action: { kind: 'in_widget_button', src_fragment: 'nav-widget.html' },
    },
    {
      id: 'q:1',
      resource_id: 102,
      role: 'graded',
      operations: [
        { id: 'a1', kind: 'answer', family: 'native_dropdowns', directive: { picks: ['Basalt'] } },
      ],
      expectations: [
        { part_path: 'stage.dropdown.selectedItem', predicate: { op: 'equal', value: 'Basalt' } },
      ],
    },
    { id: 'c:1', resource_id: 103, role: 'content' },
  ],
  scenario: [
    { screen_ref: 'n:1', expected_verdict: 'correct' },
    { screen_ref: 'q:1', expected_verdict: 'correct' },
    { screen_ref: 'c:1', expected_verdict: 'correct' },
  ],
};

const manifest = (over: Partial<AdaptiveManifest> = {}): AdaptiveManifest =>
  JSON.parse(JSON.stringify({ ...MANIFEST, ...over })) as AdaptiveManifest;

const ROUTE_SUCCESSORS = { 'n:1': 'q:1', 'q:1': 'c:1', 'c:1': '@end' };

/** Total archive facts for the three-screen fixture (§3.6b totality rule). */
const ARCHIVE_FACTS = (over: Partial<Parameters<typeof validateRouteCoverage>[0]> = {}) => ({
  screen_ids: ['n:1', 'q:1', 'c:1'],
  route_start_id: 'n:1',
  last_navigable_id: 'c:1',
  route_successors: { ...ROUTE_SUCCESSORS },
  resource_ids: { 'n:1': 101, 'q:1': 102, 'c:1': 103 },
  effective_dependencies: { 'n:1': [], 'q:1': [], 'c:1': [] },
  rule_prior_state_refs: { 'n:1': [], 'q:1': [], 'c:1': [] },
  ...over,
});

// ---------------------------------------------------------------------------
// journal-driving helpers
// ---------------------------------------------------------------------------

type NavAction = { type: 'navigation'; params: { target: string } };
type FeedbackAction = { type: 'feedback'; params: Record<string, unknown> };
type ResultEvent = { params: { correct: boolean; actions: Array<NavAction | FeedbackAction> } };

const navTo = (target: string): NavAction => ({ type: 'navigation', params: { target } });
const feedback = (): FeedbackAction => ({ type: 'feedback', params: { feedback: {} } });
const event = (correct: boolean, actions: Array<NavAction | FeedbackAction>): ResultEvent => ({
  params: { correct, actions },
});

function fireEval(
  c: AdaptiveJournalCore,
  guid: string,
  parts: Array<{ path: string; value: unknown; partGuid?: string }>,
  body: { correct: boolean; results: ResultEvent[]; llm?: { text: string } },
): number {
  const partInputs = parts.map((p, i) => ({
    attemptGuid: p.partGuid ?? `part-${guid}`,
    response: { input: { [`k${i}`]: { path: p.path, value: p.value } } },
  }));
  const handle = c.ingestRequest({
    method: 'PUT',
    url: `${ORIGIN}/state/course/s1/activity_attempt/${guid}`,
    postData: JSON.stringify({ partInputs }),
  }) as number;
  c.ingestResponse(handle, 200);
  c.ingestResponseBody(
    handle,
    JSON.stringify({
      actions: { correct: body.correct, results: body.results },
      llm_feedback: body.llm ?? null,
    }),
  );
  return handle;
}

function fireSave(
  c: AdaptiveJournalCore,
  guid: string,
  parts: Array<{ path: string; value: unknown; partGuid?: string }>,
): number {
  const partInputs = parts.map((p, i) => ({
    attemptGuid: p.partGuid ?? `part-${guid}`,
    response: { [`k${i}`]: { path: p.path, value: p.value } },
  }));
  const handle = c.ingestRequest({
    method: 'PATCH',
    url: `${ORIGIN}/state/course/s1/activity_attempt/${guid}/active`,
    postData: JSON.stringify({ partInputs }),
  }) as number;
  c.ingestResponse(handle, 200);
  c.ingestResponseBody(handle, JSON.stringify({ type: 'success' }));
  return handle;
}

function fireMint(c: AdaptiveJournalCore, targetGuid: string, mintedGuid: string): number {
  const handle = c.ingestRequest({
    method: 'POST',
    url: `${ORIGIN}/state/course/s1/activity_attempt/${targetGuid}`,
    postData: '{}',
  }) as number;
  c.ingestResponse(handle, 200);
  c.ingestResponseBody(handle, JSON.stringify({ attemptState: { attemptGuid: mintedGuid } }));
  return handle;
}

function acceptFinalization(c: AdaptiveJournalCore) {
  const handle = c.ingestRequest({
    method: 'POST',
    url: `${ORIGIN}/page_lifecycle`,
    postData: JSON.stringify({
      action: 'finalize',
      section_slug: CORR.sectionSlug,
      revision_slug: CORR.revisionSlug,
      attempt_guid: CORR.resourceAttemptGuid,
    }),
  }) as number;
  c.ingestResponse(handle, 200);
  c.ingestResponseBody(handle, JSON.stringify({ result: 'success', commandResult: 'success' }));
}

const beforeSeq = (c: AdaptiveJournalCore, handle: number): number =>
  (c.records()[handle].requestSeq as number) - 0.5;

const RECEIPT_Q1: StepReceipt = {
  stepIndex: 1,
  screenId: 'q:1',
  directive: 'native_dropdowns',
  matcher: 'local',
  expectations: [
    { part_path: 'stage.dropdown.selectedItem', predicate: { op: 'equal', value: 'Basalt' } },
  ],
};

/**
 * One green three-screen run (nav → graded → content), assembled over a real
 * journal core; `poison` hooks let each negative test bend exactly one thing.
 */
function buildRun(
  poison: {
    gradedValue?: unknown;
    gradedVerdict?: boolean;
    gradedExtraParts?: Array<{ path: string; value: unknown }>;
    duplicateGradedEval?: boolean;
    contentTerminal?: boolean;
    skipCheckClick?: boolean;
    receipts?: StepReceipt[] | null;
    omitPlans?: boolean;
  } = {},
): { snapshot: JournalSnapshot; runRecord: RunRecord } {
  const c = new AdaptiveJournalCore(() => 1_000);
  c.setRunCorrelation(CORR);

  const v0 = c.issueFence('n:1');
  const navEval = fireEval(c, 'a-n1', [], {
    correct: true,
    results: [event(true, [navTo('next')])],
  });

  const v1 = c.issueFence('q:1');
  const gradedParts = [
    {
      path: 'q:1|stage.dropdown.selectedItem',
      value: poison.gradedValue !== undefined ? poison.gradedValue : 'Basalt',
    },
    ...(poison.gradedExtraParts ?? []),
  ];
  const gradedEval = fireEval(c, 'a-q1', gradedParts, {
    correct: poison.gradedVerdict ?? true,
    results: [event(poison.gradedVerdict ?? true, [navTo('next')])],
  });
  if (poison.duplicateGradedEval) {
    fireEval(c, 'a-q1', gradedParts, { correct: true, results: [event(true, [navTo('next')])] });
  }

  const v2 = c.issueFence('c:1');
  const contentEval = fireEval(c, 'a-c1', [{ path: 'c:1|stage.done', value: 1 }], {
    correct: true,
    results: [event(true, [navTo(poison.contentTerminal === false ? 'next' : 'endOfLesson')])],
  });

  c.noteLessonEnd();
  acceptFinalization(c);
  c.markFrozenAccepted();

  const visits = [
    { screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 201 },
    { screenId: 'q:1', entrySeq: v1.seq, renderedAttemptGuid: 'a-q1', resourceId: 202 },
    { screenId: 'c:1', entrySeq: v2.seq, renderedAttemptGuid: 'a-c1', resourceId: 203 },
  ];
  const runRecord: RunRecord = {
    visits,
    permits: [
      { kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: beforeSeq(c, navEval) },
      ...(poison.skipCheckClick
        ? []
        : [
            {
              kind: 'check-click' as const,
              screenId: 'q:1',
              stepIndex: 1,
              seq: beforeSeq(c, gradedEval),
            },
          ]),
      { kind: 'check-click', screenId: 'c:1', stepIndex: 2, seq: beforeSeq(c, contentEval) },
    ],
    receipts: poison.receipts === undefined ? [RECEIPT_Q1] : (poison.receipts ?? []),
    operationFailures: [],
    plans: poison.omitPlans
      ? undefined
      : [
          recordedPlanFor(c, navEval, 0),
          recordedPlanFor(c, gradedEval, 1),
          recordedPlanFor(c, contentEval, 2),
        ],
  };
  return { snapshot: c.snapshot(), runRecord };
}

/** The driver's recorded online plan = the replay over the same body. */
function recordedPlanFor(c: AdaptiveJournalCore, handle: number, stepIndex: number) {
  const r = c.records()[handle];
  return {
    stepIndex,
    evaluationSeq: r.requestSeq,
    plan: planTransition(
      (r.actions?.results ?? []) as Parameters<typeof planTransition>[0],
      r.llmFeedback,
      false,
    ),
  };
}

const codes = (violations: ReturnType<typeof auditRun>) => violations.map((v) => v.code);

// ---------------------------------------------------------------------------
// manifest validation
// ---------------------------------------------------------------------------

test.describe('manifest v2 validation', () => {
  test('accepts the fixture manifest', () => {
    expect(() => validateAdaptiveManifest(manifest())).not.toThrow();
  });

  test('rejects duplicate ids, dangling refs, cross-screen refs and duplicate refs', () => {
    const dup = manifest();
    dup.screens.push({ ...dup.screens[2], resource_id: 999 });
    expect(() => validateAdaptiveManifest(dup)).toThrow(/duplicate screen id "c:1"/);

    const dangling = manifest();
    dangling.scenario[1].operation_refs = ['nope'];
    expect(() => validateAdaptiveManifest(dangling)).toThrow(/operation "nope" not declared/);

    const crossScreen = manifest();
    crossScreen.scenario[2].operation_refs = ['a1'];
    expect(() => validateAdaptiveManifest(crossScreen)).toThrow(/not declared by screen "c:1"/);

    const twice = manifest();
    twice.scenario[1].operation_refs = ['a1', 'a1'];
    expect(() => validateAdaptiveManifest(twice)).toThrow(/references operation "a1" twice/);
  });

  test('every screen must be routed or explicitly classified', () => {
    const silent = manifest();
    silent.screens.push({ id: 'x:1', resource_id: 900, role: 'content' });
    expect(() => validateAdaptiveManifest(silent)).toThrow(/neither on the scenario route nor/);

    const classified = manifest();
    classified.screens.push({ id: 'x:1', resource_id: 900, role: 'content' });
    classified.exclusions = [{ screen: 'x:1', reason: 'authored branch for returning students' }];
    expect(() => validateAdaptiveManifest(classified)).not.toThrow();

    const both = manifest();
    both.exclusions = [{ screen: 'c:1', reason: 'nope' }];
    expect(() => validateAdaptiveManifest(both)).toThrow(/on the route and excluded/);
  });

  test('graded screens need expectations; dependencies must name manifest screens', () => {
    const bare = manifest();
    delete (bare.screens[1] as { expectations?: unknown }).expectations;
    expect(() => validateAdaptiveManifest(bare)).toThrow(/graded and must declare/);

    const badDep = manifest();
    badDep.screens[1].dependencies = ['ghost:1'];
    expect(() => validateAdaptiveManifest(badDep)).toThrow(/dependency "ghost:1"/);

    const selfDep = manifest();
    selfDep.screens[1].dependencies = ['q:1'];
    expect(() => validateAdaptiveManifest(selfDep)).toThrow(/cannot depend on itself/);
  });

  test('predicates fail validation by NAME: unknown operator, type mismatch, empty argument', () => {
    const unknown = manifest();
    (unknown.screens[1].expectations![0] as { predicate: unknown }).predicate = {
      op: 'greaterThanOrEqual',
      value: 1,
    };
    expect(() => validateAdaptiveManifest(unknown)).toThrow(
      /unknown operator "greaterThanOrEqual"/,
    );

    const mistyped = manifest();
    (mistyped.screens[1].expectations![0] as { predicate: unknown }).predicate = {
      op: 'minLength',
      value: 'fifty',
    };
    expect(() => validateAdaptiveManifest(mistyped)).toThrow(/argument type does not match/);

    const empty = manifest();
    (empty.screens[1].expectations![0] as { predicate: unknown }).predicate = {
      op: 'containsAnyOf',
      value: [],
    };
    expect(() => validateAdaptiveManifest(empty)).toThrow(/empty condition argument/);

    const emptyAll = manifest();
    (emptyAll.screens[1].expectations![0] as { predicate: unknown }).predicate = { all: [] };
    expect(() => validateAdaptiveManifest(emptyAll)).toThrow(/non-empty predicate array/);
  });

  test('route coverage is a bijection against the archive inventory', () => {
    const m = manifest();
    const facts = (ids: string[]) => ARCHIVE_FACTS({ screen_ids: ids });
    expect(() => validateRouteCoverage(facts(['n:1', 'q:1', 'c:1']), m)).not.toThrow();
    expect(() => validateRouteCoverage(facts(['n:1', 'q:1']), m)).toThrow(
      /does not exist in the archive/,
    );
    expect(() => validateRouteCoverage(facts(['n:1', 'q:1', 'c:1', 'ghost:9']), m)).toThrow(
      /"ghost:9" has no screen definition/,
    );
    expect(() => validateRouteCoverage(facts(['n:1', 'n:1', 'q:1', 'c:1']), m)).toThrow(
      /duplicate/,
    );
  });

  test('the scenario must end at the archive-proven last navigable entry (§3.5)', () => {
    const m = manifest();
    expect(() => validateRouteCoverage(ARCHIVE_FACTS({ last_navigable_id: 'q:1' }), m)).toThrow(
      /archive proves "q:1" is the last navigable entry/,
    );
  });

  test('the scenario must start at the archive-selected route entry — a suffix cannot hide its head (§3.8)', () => {
    // a proper SUFFIX of the selected route, its omitted head classified as
    // an exclusion: passes bijection, every remaining edge, and the terminal
    // check — only the proven route start rejects it
    const suffix = manifest({
      scenario: [
        { screen_ref: 'q:1', expected_verdict: 'correct' },
        { screen_ref: 'c:1', expected_verdict: 'correct' },
      ],
      exclusions: [{ screen: 'n:1', reason: 'pretending the head is off-route' }],
    });
    expect(() => validateRouteCoverage(ARCHIVE_FACTS(), suffix)).toThrow(
      /archive proves "n:1" is the selected route's entry/,
    );
  });

  test('every scenario EDGE is archive-proven — a permuted middle fails (§3.8)', () => {
    const m = manifest();
    expect(() => validateRouteCoverage(ARCHIVE_FACTS(), m)).not.toThrow();

    const permuted = manifest();
    // archive says n:1 -> q:1 -> c:1; a scenario visiting q:1 last would have
    // passed an endpoints-only check if c:1 were also a navigable end
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({ route_successors: { 'n:1': 'c:1', 'c:1': 'q:1', 'q:1': '@end' } }),
        permuted,
      ),
    ).toThrow(/scenario edge 0/);

    const missing = manifest();
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({ route_successors: { 'n:1': 'q:1', 'q:1': 'c:1' } }),
        missing,
      ),
    ).toThrow(/no route successor for scenario screen "c:1"/);
  });

  test('both dependency-proof maps are TOTAL over the inventory — absent keys fail closed (§3.6b)', () => {
    const m = manifest();
    const missingKey = ARCHIVE_FACTS();
    delete (missingKey.rule_prior_state_refs as Record<string, string[]>)['q:1'];
    expect(() => validateRouteCoverage(missingKey, m)).toThrow(
      /no rule_prior_state_refs entry for screen "q:1" — missing evidence/,
    );

    const extraKey = ARCHIVE_FACTS();
    (extraKey.effective_dependencies as Record<string, string[]>)['ghost:9'] = [];
    expect(() => validateRouteCoverage(extraKey, m)).toThrow(
      /effective_dependencies names "ghost:9", which is not in the inventory/,
    );
  });

  test('archive rule references demand a declared dependency even when none is declared (§3.6b)', () => {
    const m = manifest();
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({
          rule_prior_state_refs: { 'n:1': [], 'q:1': [], 'c:1': ['q:1|stage.sim.Correct'] },
        }),
        m,
      ),
    ).toThrow(/rule reads prior state of "q:1" without declaring it as a dependency/);
  });

  test('declared dependencies must belong to the archive effective set — bidirectional (§3.6b)', () => {
    const m = manifest();
    m.screens[2].dependencies = ['q:1'];
    m.screens[2].expectations = [
      { part_path: 'q:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
    ];

    // declared dependency outside the archive's effective set → fail
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({
          effective_dependencies: { 'n:1': [], 'q:1': [], 'c:1': ['n:1'] },
        }),
        m,
      ),
    ).toThrow(/outside the archive's effective dependency set/);

    // rule prior-state reference with no covering expectation → fail (underdeclared)
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({
          effective_dependencies: { 'n:1': [], 'q:1': [], 'c:1': ['q:1'] },
          rule_prior_state_refs: {
            'n:1': [],
            'q:1': [],
            'c:1': ['q:1|stage.sim.Correct', 'q:1|stage.sim.Other'],
          },
        }),
        m,
      ),
    ).toThrow(/prior state "q:1\|stage.sim.Other" with no covering/);

    // fully proven → accept
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({
          effective_dependencies: { 'n:1': [], 'q:1': [], 'c:1': ['q:1'] },
          rule_prior_state_refs: { 'n:1': [], 'q:1': [], 'c:1': ['q:1|stage.sim.Correct'] },
        }),
        m,
      ),
    ).not.toThrow();
  });

  test('operation refs omitted expand to every local operation in definition order (§3.8)', () => {
    const m = manifest();
    const screen = m.screens[1];
    screen.operations!.push({ id: 'a2', kind: 'gate', gate: 'carousel_view' });
    expect(
      resolveOperations(screen, { screen_ref: 'q:1', expected_verdict: 'correct' }).map(
        (op) => op.id,
      ),
    ).toEqual(['a1', 'a2']);
    expect(
      resolveOperations(screen, {
        screen_ref: 'q:1',
        expected_verdict: 'correct',
        operation_refs: ['a2', 'a1'],
      }).map((op) => op.id),
    ).toEqual(['a1', 'a2']);
  });
});

// ---------------------------------------------------------------------------
// predicate matrix
// ---------------------------------------------------------------------------

test.describe('predicate matrix — accept and reject per operator', () => {
  const cases: Array<[string, Parameters<typeof evaluatePredicate>[0], unknown, unknown]> = [
    ['equal', { op: 'equal', value: 'Basalt' }, ' basalt ', 'granite'],
    ['equal number-string', { op: 'equal', value: 3 }, '3', '4'],
    ['notEqual', { op: 'notEqual', value: 'granite' }, 'basalt', 'granite'],
    [
      'contains',
      { op: 'contains', value: ['disaster', 'hazard'] },
      'A disaster and a Hazard',
      'a disaster only',
    ],
    ['notContains', { op: 'notContains', value: 'lava' }, 'magma chamber', 'lava flow'],
    ['containsAnyOf', { op: 'containsAnyOf', value: [1, 2] }, '[2,5]', '[5,9]'],
    ['notContainsAnyOf', { op: 'notContainsAnyOf', value: [1, 2] }, '[5,9]', '[2,5]'],
    ['containsOnly', { op: 'containsOnly', value: [1, 2] }, '[2,1]', '[1,2,3]'],
    ['greaterThan', { op: 'greaterThan', value: 3 }, '4', '3'],
    ['greaterThanInclusive', { op: 'greaterThanInclusive', value: 3 }, '3', '2.9'],
    ['lessThan', { op: 'lessThan', value: 3 }, '2', '3'],
    ['lessThanInclusive', { op: 'lessThanInclusive', value: 3 }, '3', '3.1'],
    ['minLength', { op: 'minLength', value: 5 }, '  exactly long enough  ', 'tiny'],
    ['maxLength', { op: 'maxLength', value: 4 }, ' tiny ', 'far too long'],
    ['selectedCountEqual', { op: 'selectedCountEqual', value: 2 }, '[1,2]', '[1]'],
    ['selectedCountNotEqual', { op: 'selectedCountNotEqual', value: 2 }, '[1]', '[1,2]'],
  ];
  for (const [name, predicate, accept, reject] of cases) {
    test(name, () => {
      expect(evaluatePredicate(predicate, accept), `${name} accept`).toBe(true);
      expect(evaluatePredicate(predicate, reject), `${name} reject`).toBe(false);
    });
  }

  test('selectedChoices normalizes BOTH measured encodings to a number list', () => {
    expect(selectedCount('[1,2,3]')).toBe(3);
    expect(selectedCount([1, 2, 3])).toBe(3);
    expect(selectedCount('[]')).toBe(0);
    expect(selectedCount('not an array')).toBe(0);
  });

  test('all is explicit conjunction', () => {
    const both = {
      all: [
        { op: 'contains' as const, value: 'disaster' },
        { op: 'contains' as const, value: 'hazard' },
      ],
    };
    expect(evaluatePredicate(both, 'disaster and hazard')).toBe(true);
    expect(evaluatePredicate(both, 'disaster only')).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// planner — the footer's exact selection algorithm
// ---------------------------------------------------------------------------

test.describe('transition planner — combineFeedback branches (DeckLayoutFooter:420-444)', () => {
  const nav = (target: string, correct = true) => event(correct, [navTo(target)]);
  const fb = (correct = true) => event(correct, [feedback()]);

  test('combine_feedback false processes results[0] alone', () => {
    const results = [nav('next'), fb()];
    expect(selectProcessedEvents(results, false)).toEqual([results[0]]);
    expect(planTransition(results, null, false)).toEqual({ kind: 'auto-navigate', target: 'next' });
  });

  test('ALL results when every result carries the same navigation target', () => {
    const results = [nav('q:2'), event(true, [feedback(), navTo('q:2')])];
    expect(selectProcessedEvents(results, true)).toEqual(results);
    expect(planTransition(results, null, true)).toEqual({
      kind: 'feedback',
      ack: { kind: 'navigate', target: 'q:2' },
    });
  });

  test('FIRST only when the first event navigates AND the aggregate verdict is false', () => {
    const results = [nav('q:3', false), fb(true)];
    expect(selectProcessedEvents(results, true)).toEqual([results[0]]);
    expect(planTransition(results, null, true)).toEqual({ kind: 'auto-navigate', target: 'q:3' });
  });

  test('ALL results otherwise — first navigates but every result is correct', () => {
    const results = [nav('q:3', true), fb(true)];
    expect(selectProcessedEvents(results, true)).toEqual(results);
    expect(planTransition(results, null, true)).toEqual({
      kind: 'feedback',
      ack: { kind: 'navigate', target: 'q:3' },
    });
  });

  test('ALL results when the first does not navigate', () => {
    const results = [fb(false), nav('q:4', false)];
    expect(selectProcessedEvents(results, true)).toEqual(results);
  });

  test('endOfLesson is terminal; LLM feedback opens feedback; nothing derives none', () => {
    expect(planTransition([nav('endOfLesson')], null, false)).toEqual({ kind: 'terminal' });
    expect(planTransition([nav('next')], { text: 'AI says hi' }, false)).toEqual({
      kind: 'feedback',
      ack: { kind: 'navigate', target: 'next' },
    });
    expect(planTransition([event(true, [])], null, false)).toEqual({ kind: 'none' });
    expect(planTransition([], null, false)).toEqual({ kind: 'none' });
  });
});

// ---------------------------------------------------------------------------
// oracle — invariant inventory over real journal snapshots
// ---------------------------------------------------------------------------

test.describe('auditRun over a driven journal', () => {
  test('a green three-screen run audits to zero violations', () => {
    const { snapshot, runRecord } = buildRun();
    const violations = auditRun(manifest(), runRecord, snapshot);
    expect(formatViolations(violations)).toBe('auditRun: no violations');
  });

  test('a wrong graded verdict is a violation', () => {
    const { snapshot, runRecord } = buildRun({ gradedVerdict: false });
    expect(codes(auditRun(manifest(), runRecord, snapshot))).toContain('verdict-not-correct');
  });

  test('a payload that fails its expectation predicate is a violation', () => {
    const { snapshot, runRecord } = buildRun({ gradedValue: 'granite' });
    expect(codes(auditRun(manifest(), runRecord, snapshot))).toContain('payload-mismatch');
  });

  test('a graded step without a receipt is a violation', () => {
    const { snapshot, runRecord } = buildRun({ receipts: null });
    expect(codes(auditRun(manifest(), runRecord, snapshot))).toContain('receipt-missing');
  });

  test('an unlicensed duplicate evaluation has no causal edge and breaks the count', () => {
    const { snapshot, runRecord } = buildRun({ duplicateGradedEval: true });
    const found = codes(auditRun(manifest(), runRecord, snapshot));
    expect(found).toContain('evaluation-no-causal-edge');
    expect(found).toContain('evaluation-count');
  });

  test('an evaluation with no licensing permit at all is edge-less', () => {
    const { snapshot, runRecord } = buildRun({ skipCheckClick: true });
    expect(codes(auditRun(manifest(), runRecord, snapshot))).toContain('evaluation-no-causal-edge');
  });

  test('a route order mismatch is a violation', () => {
    const reordered = manifest();
    reordered.scenario = [reordered.scenario[0], reordered.scenario[2], reordered.scenario[1]];
    const { snapshot, runRecord } = buildRun();
    expect(codes(auditRun(reordered, runRecord, snapshot))).toContain('route-shape');
  });

  test('cross-screen contamination: a payload prefix of another manifest screen', () => {
    const { snapshot, runRecord } = buildRun({
      gradedExtraParts: [{ path: 'c:1|stage.smuggled', value: 'x' }],
    });
    expect(codes(auditRun(manifest(), runRecord, snapshot))).toContain('provenance-contamination');
  });

  test('a declared dependency or whitelisted ancestor prefix is NOT contamination', () => {
    const m = manifest();
    m.screens[1].layer_parents = ['layer:parent'];
    const { snapshot, runRecord } = buildRun({
      gradedExtraParts: [{ path: 'layer:parent|stage.shared', value: 'x' }],
    });
    expect(codes(auditRun(m, runRecord, snapshot))).toEqual([]);
  });

  test('an operation failure is positive evidence with expected-step attribution', () => {
    const { snapshot, runRecord } = buildRun();
    runRecord.operationFailures.push({
      kind: 'identity-unresolved',
      screenId: null,
      expectedStepIndex: 1,
    });
    const violations = auditRun(manifest(), runRecord, snapshot);
    const failure = violations.find((v) => v.code === 'operation-failure');
    expect(failure?.stepIndex).toBe(1);
  });

  test('a terminal plan before the last step is an unfulfilled obligation', () => {
    const m = manifest();
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    const navEval = fireEval(c, 'a-n1', [], {
      correct: true,
      results: [event(true, [navTo('endOfLesson')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [
        { kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: beforeSeq(c, navEval) },
      ],
      receipts: [],
      operationFailures: [],
    };
    const found = auditRun(m, runRecord, c.snapshot());
    expect(codes(found)).toContain('obligation-unfulfilled');
  });
});

test.describe('navigation sequence rule', () => {
  function navRun(build: (c: AdaptiveJournalCore) => void): ReturnType<typeof buildRun> {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    build(c);
    c.beginSeal();
    c.finishSeal();
    return {
      snapshot: c.snapshot(),
      runRecord: {
        visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
        permits: [{ kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: v0.seq + 0.5 }],
        receipts: [],
        operationFailures: [],
      },
    };
  }
  const NAV_ONLY = manifest({
    screens: [MANIFEST.screens[0]],
    scenario: [{ screen_ref: 'n:1', expected_verdict: 'correct' }],
  });

  test('an incorrect non-navigating singleton is a violation even if the deck advanced', () => {
    const { snapshot, runRecord } = navRun((c) => {
      fireEval(c, 'a-n1', [], { correct: false, results: [event(false, [feedback()])] });
    });
    const found = auditRun(NAV_ONLY, runRecord, snapshot);
    expect(codes(found)).toContain('navigation-sequence');
    expect(formatViolations(found)).toMatch(/rotation/);
  });

  test('the measured rotation is legal: incorrect check, causal mint, correct navigating check', () => {
    const { snapshot, runRecord } = navRun((c) => {
      fireEval(c, 'a-n1', [], { correct: false, results: [event(false, [feedback()])] });
      fireMint(c, 'a-n1', 'a-n1b');
      fireEval(c, 'a-n1b', [], { correct: true, results: [event(true, [navTo('next')])] });
    });
    // the rotation itself is legal — the only finding is the §3.2 sentinel
    // for a sealed snapshot carrying no failure evidence at all
    expect(codes(auditRun(NAV_ONLY, runRecord, snapshot))).toEqual(['seal-without-evidence']);
  });

  test('a split rotation without its causal mint is rejected as one whole sequence', () => {
    const { snapshot, runRecord } = navRun((c) => {
      fireEval(c, 'a-n1', [], { correct: false, results: [event(false, [feedback()])] });
      fireEval(c, 'a-n1b', [], { correct: true, results: [event(true, [navTo('next')])] });
    });
    const found = auditRun(NAV_ONLY, runRecord, snapshot);
    expect(codes(found)).toContain('navigation-sequence');
    // the un-minted second attempt also breaks lineage
    expect(codes(found)).toContain('lineage');
  });

  test('three owned evaluations can never be licensed', () => {
    const { snapshot, runRecord } = navRun((c) => {
      fireEval(c, 'a-n1', [], { correct: false, results: [event(false, [feedback()])] });
      fireMint(c, 'a-n1', 'a-n1b');
      fireEval(c, 'a-n1b', [], { correct: true, results: [event(true, [navTo('next')])] });
      fireEval(c, 'a-n1b', [], { correct: true, results: [event(true, [navTo('next')])] });
    });
    expect(codes(auditRun(NAV_ONLY, runRecord, snapshot))).toContain('navigation-sequence');
  });
});

test.describe('savedBarrier temporal audit and distinct-path min_count', () => {
  test('a save inside the barrier window satisfies it; mid-gesture or missing saves fail', () => {
    const receiptWithBarrier = (readbackSeq: number): StepReceipt => ({
      ...RECEIPT_Q1,
      savedBarrierPrefixes: ['q:1|stage.widget'],
      readbackCompletedSeq: readbackSeq,
    });

    // green: save lands after readback and before check-click
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const readbackSeq = c.issueFence('q:1').seq; // stands in for the driver's readback stamp
    fireSave(c, 'a-q1', [{ path: 'q:1|stage.widget.state', value: 'ready' }]);
    const gradedEval = fireEval(
      c,
      'a-q1',
      [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
      { correct: true, results: [event(true, [navTo('endOfLesson')])] },
    );
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const m = manifest({
      screens: [MANIFEST.screens[1]],
      scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
    });
    const base: RunRecord = {
      visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
      permits: [
        { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
      ],
      receipts: [{ ...receiptWithBarrier(readbackSeq), stepIndex: 0 }],
      operationFailures: [],
      plans: [recordedPlanFor(c, gradedEval, 0)],
    };
    expect(codes(auditRun(m, base, c.snapshot()))).toEqual([]);

    // the same save cannot satisfy a barrier whose readback completed AFTER it
    const midGesture: RunRecord = {
      ...base,
      receipts: [{ ...receiptWithBarrier(readbackSeq + 4), stepIndex: 0 }],
    };
    expect(codes(auditRun(m, midGesture, c.snapshot()))).toContain('saved-barrier');
  });

  test('min_count counts DISTINCT satisfied paths, never duplicated array entries', () => {
    const fibExpectation = {
      part_path_prefix: 'q:1|stage.fib',
      predicate: { op: 'contains' as const, value: 'dense' },
      min_count: 2,
    };
    const m = manifest();
    m.screens[1].expectations = [fibExpectation];
    const fibReceipt: StepReceipt[] = [{ ...RECEIPT_Q1, expectations: [fibExpectation] }];

    const duplicated = buildRun({
      receipts: fibReceipt,
      gradedExtraParts: [
        { path: 'q:1|stage.fib.blank1', value: 'more dense' },
        { path: 'q:1|stage.fib.blank1', value: 'more dense' },
      ],
    });
    expect(codes(auditRun(m, duplicated.runRecord, duplicated.snapshot))).toContain(
      'payload-mismatch',
    );

    const distinct = buildRun({
      receipts: fibReceipt,
      gradedExtraParts: [
        { path: 'q:1|stage.fib.blank1', value: 'more dense' },
        { path: 'q:1|stage.fib.blank2', value: 'less dense' },
      ],
    });
    expect(codes(auditRun(m, distinct.runRecord, distinct.snapshot))).toEqual([]);
  });
});

test.describe('committed prior state (§3.6)', () => {
  const DEP_RECEIPT: StepReceipt = {
    stepIndex: 1,
    screenId: 'q:2',
    directive: 'cross_screen',
    matcher: 'cross_screen',
    expectations: [{ part_path: 'q:1|stage.sim.Correct', predicate: { op: 'equal', value: true } }],
  };

  function crossRun(build: (c: AdaptiveJournalCore) => { checking: number }) {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const { checking } = build(c);
    c.beginSeal();
    c.finishSeal();
    return { snapshot: c.snapshot(), checkingRecord: c.snapshot().records[checking] };
  }

  test('the latest committed save of the newest attempt satisfies the receipt', () => {
    const { snapshot, checkingRecord } = crossRun((c) => {
      fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: true }]);
      const checking = fireEval(c, 'a-q2', [], {
        correct: true,
        results: [event(true, [navTo('next')])],
      });
      return { checking };
    });
    expect(auditCrossScreenReceipt(snapshot, DEP_RECEIPT, [['a-dep']], checkingRecord)).toEqual([]);
  });

  test('a fresh attempt mint alone shifts the lineage — the stale save cannot pass', () => {
    const { snapshot, checkingRecord } = crossRun((c) => {
      fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: true }]);
      fireMint(c, 'a-dep', 'a-dep2');
      const checking = fireEval(c, 'a-q2', [], {
        correct: true,
        results: [event(true, [navTo('next')])],
      });
      return { checking };
    });
    const found = auditCrossScreenReceipt(
      snapshot,
      DEP_RECEIPT,
      [['a-dep', 'a-dep2']],
      checkingRecord,
    );
    expect(found.map((v) => v.code)).toContain('payload-mismatch');
  });

  test('a mutation inside the check request→response window is rejected as unstable', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: true }]);
    const checking = c.ingestRequest({
      method: 'PUT',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-q2`,
      postData: JSON.stringify({ partInputs: [] }),
    }) as number;
    // poisoned save lands between the check request and its response
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: false }]);
    c.ingestResponse(checking, 200);
    c.ingestResponseBody(
      checking,
      JSON.stringify({ actions: { correct: true, results: [event(true, [navTo('next')])] } }),
    );
    c.beginSeal();
    c.finishSeal();
    const snapshot = c.snapshot();
    const found = auditCrossScreenReceipt(
      snapshot,
      DEP_RECEIPT,
      [['a-dep']],
      snapshot.records[checking],
    );
    expect(found[0]?.facts.detail).toBe('unstable-dependency');
    expect(formatViolations(found)).toMatch(/mutated inside the check request→response window/);
  });

  test('the newest save of a part attempt REPLACES its response — never a per-path merge', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.A', value: 1 }]);
    fireSave(c, 'a-dep', [
      { path: 'q:1|stage.sim.A', value: 2 },
      { path: 'q:1|stage.sim.B', value: 3 },
    ]);
    // a later save of the SAME part attempt without A: A must not survive
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 4 }]);
    c.beginSeal();
    c.finishSeal();
    const { state, ambiguousParts } = committedPriorState(c.snapshot(), ['a-dep'], 999);
    expect(ambiguousParts).toEqual([]);
    expect(state.get('q:1|stage.sim.A')).toBeUndefined();
    expect(state.get('q:1|stage.sim.B')).toBe(4);
  });

  test('multiple part attempts for one part_id FAIL CLOSED — the wire cannot prove row order (§3.6)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    // part `sim` shows two part-attempt guids; observation order is not
    // creation-row order, so the matcher must refuse rather than guess —
    // part `other` stays unambiguous and usable
    fireSave(c, 'a-dep', [
      { path: 'q:1|stage.sim.A', value: 1, partGuid: 'pa-sim-1' },
      { path: 'q:1|stage.other.C', value: 9, partGuid: 'pa-other-1' },
    ]);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 7, partGuid: 'pa-sim-2' }]);
    c.beginSeal();
    c.finishSeal();
    const { state, ambiguousParts } = committedPriorState(c.snapshot(), ['a-dep'], 999);
    expect(ambiguousParts).toEqual(['sim']);
    expect(state.get('q:1|stage.sim.A')).toBeUndefined();
    expect(state.get('q:1|stage.sim.B')).toBeUndefined();
    expect(state.get('q:1|stage.other.C')).toBe(9);

    // ...and the crossed ordering — newer guid first, older guid's delayed
    // save afterwards — is exactly as unprovable, same refusal
    const crossed = new AdaptiveJournalCore(() => 1_000);
    fireSave(crossed, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 7, partGuid: 'pa-sim-2' }]);
    fireSave(crossed, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 99, partGuid: 'pa-sim-1' }]);
    crossed.beginSeal();
    crossed.finishSeal();
    const late = committedPriorState(crossed.snapshot(), ['a-dep'], 999);
    expect(late.ambiguousParts).toEqual(['sim']);
    expect(late.state.get('q:1|stage.sim.B')).toBeUndefined();
  });

  test('ambiguous part order surfaces as a named fail-closed violation via the receipt audit', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: true, partGuid: 'pa-1' }]);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: true, partGuid: 'pa-2' }]);
    const checking = fireEval(c, 'a-q2', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    c.beginSeal();
    c.finishSeal();
    const found = auditCrossScreenReceipt(
      c.snapshot(),
      DEP_RECEIPT,
      [['a-dep']],
      c.snapshot().records[checking],
    );
    expect(
      found.some((v) => v.code === 'payload-mismatch' && v.facts.detail === 'ambiguous-part-order'),
    ).toBe(true);
  });
});

test.describe('sealed and freeze-failure audits', () => {
  test('an owned unresolved candidate is a violation on a sealed run — fail-closed', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    c.ingestRequest({
      method: 'PUT',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-q1`,
      postData: JSON.stringify({ partInputs: [] }),
    });
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
      permits: [],
      receipts: [],
      operationFailures: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1]],
      scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
    });
    expect(codes(auditRun(m, runRecord, c.snapshot()))).toContain('unresolved-candidate-owned');
  });

  test('a sealed ordinary bail always audits to at least one violation', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [],
      receipts: [],
      operationFailures: [
        { kind: 'widget-button-unavailable', screenId: 'n:1', expectedStepIndex: 0 },
      ],
    };
    const found = auditRun(manifest(), runRecord, c.snapshot());
    expect(found.length).toBeGreaterThan(0);
    expect(codes(found)).toContain('operation-failure');
  });

  test('the freeze-timeout record maps to a violation even in a COMPLETE sealed set', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    c.noteLessonEnd();
    c.markFreezeTimeout();
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [],
      receipts: [],
      operationFailures: [],
    };
    const found = auditRun(manifest(), runRecord, c.snapshot());
    expect(codes(found)).toContain('freeze-timeout');
    expect(c.snapshot().sealIncomplete).toBe(false);
  });

  test('a completed-failure freeze surfaces the finalization defect as a terminal obligation', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    const navEval = fireEval(c, 'a-n1', [], {
      correct: true,
      results: [event(true, [navTo('endOfLesson')])],
    });
    c.noteLessonEnd();
    c.enterTerminalization('already_submitted');
    c.markFrozenCompletedFailure();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [
        { kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: beforeSeq(c, navEval) },
      ],
      receipts: [],
      operationFailures: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[0]],
      scenario: [{ screen_ref: 'n:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    const terminal = found.find((v) => v.code === 'terminal-obligation');
    expect(terminal?.facts.reason).toBe('already_submitted');
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-1 witnesses (§8 rows surfaced by review)
// ---------------------------------------------------------------------------

const betweenSeq = (c: AdaptiveJournalCore, handle: number): number => {
  const r = c.records()[handle];
  return ((r.requestSeq as number) + (r.responseSeq as number)) / 2;
};

test.describe('recorded plan vs replay (§3.5 replay agreement)', () => {
  test('a recorded plan that disagrees with the replay is a divergence', () => {
    const { snapshot, runRecord } = buildRun();
    (runRecord.plans![0] as { plan: unknown }).plan = { kind: 'terminal' };
    const found = auditRun(manifest(), runRecord, snapshot);
    expect(codes(found)).toContain('plan-divergence');
    expect(found.find((v) => v.code === 'plan-divergence')?.facts.planKind).toBe('terminal');
  });

  test('a usable evaluation with NO recorded plan is a divergence under a full audit', () => {
    const { snapshot, runRecord } = buildRun({ omitPlans: true });
    const found = auditRun(manifest(), runRecord, snapshot);
    expect(
      found.filter(
        (v) => v.code === 'plan-divergence' && v.facts.detail === 'missing-recorded-plan',
      ).length,
    ).toBeGreaterThan(0);
  });
});

test.describe('obligations are bounded by the RESPONSE that created the plan (§3.5 causality)', () => {
  function feedbackRun(ackAt: 'between' | 'after') {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const gradedEval = fireEval(
      c,
      'a-q1',
      [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
      { correct: true, results: [event(true, [feedback()])] },
    );
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const ackSeq =
      ackAt === 'between'
        ? betweenSeq(c, gradedEval)
        : (c.records()[gradedEval].responseSeq as number) + 0.5;
    const runRecord: RunRecord = {
      visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
      permits: [
        { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
        { kind: 'feedback-ack', screenId: 'q:1', stepIndex: 0, seq: ackSeq },
      ],
      receipts: [{ ...RECEIPT_Q1, stepIndex: 0 }],
      operationFailures: [],
      plans: [recordedPlanFor(c, gradedEval, 0)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1]],
      scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
    });
    return auditRun(m, runRecord, c.snapshot());
  }

  test('an ack stamped between request and response fulfils nothing', () => {
    const found = feedbackRun('between');
    expect(
      found.some((v) => v.code === 'obligation-unfulfilled' && v.facts.detail === 'no-ack'),
    ).toBe(true);
  });

  test('the same ack after the response fulfils the feedback plan', () => {
    const found = feedbackRun('after');
    expect(
      found.some((v) => v.code === 'obligation-unfulfilled' && v.facts.detail === 'no-ack'),
    ).toBe(false);
  });
});

test.describe('saved-barrier absence is gated by the §3.2 matrix', () => {
  test('a sealed OPEN window draws no saved-barrier absence conclusion', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const gradedEval = fireEval(
      c,
      'a-q1',
      [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
      { correct: true, results: [event(true, [navTo('next')])] },
    );
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
      permits: [
        { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
      ],
      receipts: [
        {
          ...RECEIPT_Q1,
          stepIndex: 0,
          savedBarrierPrefixes: ['q:1|stage.widget'],
          readbackCompletedSeq: v0.seq,
        },
      ],
      operationFailures: [],
      plans: [recordedPlanFor(c, gradedEval, 0)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1]],
      scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
    });
    // no save exists at all — but the window is open at seal, so no absence
    expect(codes(auditRun(m, runRecord, c.snapshot()))).not.toContain('saved-barrier');
  });
});

test.describe('permit inventory (§3.4)', () => {
  test('a permit naming another screen, duplicates and wrong-role permits are violations', () => {
    const { snapshot, runRecord } = buildRun();
    runRecord.permits.push(
      {
        kind: 'feedback-ack',
        screenId: 'x:9',
        stepIndex: 2,
        seq: runRecord.visits[2].entrySeq + 0.1,
      },
      {
        kind: 'check-click',
        screenId: 'q:1',
        stepIndex: 1,
        seq: runRecord.visits[1].entrySeq + 0.1,
      },
      {
        kind: 'widget-button',
        screenId: 'q:1',
        stepIndex: 1,
        seq: runRecord.visits[1].entrySeq + 0.2,
      },
    );
    const found = auditRun(manifest(), runRecord, snapshot);
    const details = found
      .filter((v) => v.code === 'permit-mismatch')
      .map((v) => v.facts.detail)
      .sort();
    expect(details).toContain('screen-mismatch');
    expect(details).toContain('duplicate');
    expect(details).toContain('wrong-role');
  });

  test('an evaluation-capable permit that licensed nothing is a violation on a full audit', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('c:1');
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'c:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-c1', resourceId: 1 }],
      permits: [{ kind: 'check-click', screenId: 'c:1', stepIndex: 0, seq: v0.seq + 0.5 }],
      receipts: [],
      operationFailures: [],
      plans: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[2]],
      scenario: [{ screen_ref: 'c:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(found.some((v) => v.code === 'permit-mismatch' && v.facts.detail === 'unused')).toBe(
      true,
    );
  });
});

test.describe('cross-screen grading THROUGH auditRun (§3.6)', () => {
  const CROSS_MANIFEST: AdaptiveManifest = {
    screens: [
      { id: 's:1', resource_id: 301, role: 'content' },
      {
        id: 'q:2',
        resource_id: 302,
        role: 'graded',
        dependencies: ['s:1'],
        expectations: [
          { part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
        ],
      },
    ],
    scenario: [
      { screen_ref: 's:1', expected_verdict: 'correct' },
      { screen_ref: 'q:2', expected_verdict: 'correct' },
    ],
  };
  const CROSS_RECEIPT: StepReceipt = {
    stepIndex: 1,
    screenId: 'q:2',
    directive: 'cross_screen',
    matcher: 'cross_screen',
    expectations: [{ part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } }],
  };

  function crossAudit(simValue: unknown, receipt: StepReceipt = CROSS_RECEIPT) {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('s:1');
    const contentEval = fireEval(c, 'a-s1', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    fireSave(c, 'a-s1', [{ path: 's:1|stage.sim.Correct', value: simValue }]);
    const v1 = c.issueFence('q:2');
    const checkingEval = fireEval(c, 'a-q2', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [
        { screenId: 's:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-s1', resourceId: 1 },
        { screenId: 'q:2', entrySeq: v1.seq, renderedAttemptGuid: 'a-q2', resourceId: 2 },
      ],
      permits: [
        { kind: 'check-click', screenId: 's:1', stepIndex: 0, seq: beforeSeq(c, contentEval) },
        { kind: 'check-click', screenId: 'q:2', stepIndex: 1, seq: beforeSeq(c, checkingEval) },
      ],
      receipts: [receipt],
      operationFailures: [],
      plans: [recordedPlanFor(c, contentEval, 0), recordedPlanFor(c, checkingEval, 1)],
    };
    return auditRun(JSON.parse(JSON.stringify(CROSS_MANIFEST)), runRecord, c.snapshot());
  }

  test('committed prior state satisfying the receipt audits clean through the public contract', () => {
    expect(codes(crossAudit(true))).toEqual([]);
  });

  test('committed prior state failing the expectation is caught by auditRun itself', () => {
    expect(codes(crossAudit(false))).toContain('payload-mismatch');
  });

  test('a receipt whose matcher contradicts the manifest dependencies is rejected', () => {
    const found = crossAudit(true, { ...CROSS_RECEIPT, matcher: 'local' });
    expect(found.some((v) => v.code === 'receipt-mismatch' && v.facts.detail === 'matcher')).toBe(
      true,
    );
  });
});

test.describe('remaining §8 rows', () => {
  test('every operation-failure union member maps to its violation', () => {
    const kinds = [
      'identity-unresolved',
      'readiness-timeout',
      'answer-failed',
      'readback-failed',
      'barrier-timeout',
      'check-click-no-effect',
      'feedback-never-opened',
      'ack-no-effect',
      'widget-button-unavailable',
      'navigation-timeout',
    ] as const;
    const { snapshot, runRecord } = buildRun();
    const stepScreens = ['n:1', 'q:1', 'c:1'];
    runRecord.operationFailures = kinds.map((kind, n) => ({
      kind,
      screenId: kind === 'identity-unresolved' ? null : stepScreens[n % 3],
      expectedStepIndex: n % 3,
    }));
    const found = auditRun(manifest(), runRecord, snapshot);
    const mapped = found.filter((v) => v.code === 'operation-failure');
    // exact-length: toEqual IGNORES undefined array items, so a count
    // mismatch must be asserted explicitly or extras slip through
    expect(mapped.length).toBe(kinds.length);
    expect(mapped.map((v) => v.facts.failureKind).sort()).toEqual([...kinds].sort());
  });

  test('final-step navigation to any target but "next" cannot be fulfilled by lesson end', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const gradedEval = fireEval(
      c,
      'a-q1',
      [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
      { correct: true, results: [event(true, [navTo('prev')])] },
    );
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
      permits: [
        { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
      ],
      receipts: [{ ...RECEIPT_Q1, stepIndex: 0 }],
      operationFailures: [],
      plans: [recordedPlanFor(c, gradedEval, 0)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1]],
      scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(
      found.some(
        (v) => v.code === 'obligation-unfulfilled' && v.facts.detail === 'target-not-next',
      ),
    ).toBe(true);
  });

  test('pre-entry traffic on a NON-navigation first screen is illegal; legal on navigation', () => {
    const build = (firstScreen: 'q:1' | 'n:1') => {
      const c = new AdaptiveJournalCore(() => 1_000);
      c.setRunCorrelation(CORR);
      const guid = firstScreen === 'q:1' ? 'a-q1' : 'a-n1';
      const parts =
        firstScreen === 'q:1' ? [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }] : [];
      const preEval = fireEval(c, guid, parts, {
        correct: true,
        results: [event(true, [navTo('endOfLesson')])],
      });
      const v0 = c.issueFence(firstScreen);
      c.noteLessonEnd();
      acceptFinalization(c);
      c.markFrozenAccepted();
      const runRecord: RunRecord = {
        visits: [
          { screenId: firstScreen, entrySeq: v0.seq, renderedAttemptGuid: guid, resourceId: 1 },
        ],
        permits:
          firstScreen === 'q:1'
            ? [{ kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, preEval) }]
            : [{ kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: v0.seq + 0.5 }],
        receipts: firstScreen === 'q:1' ? [{ ...RECEIPT_Q1, stepIndex: 0 }] : [],
        operationFailures: [],
        plans: [recordedPlanFor(c, preEval, 0)],
      };
      const m = manifest({
        screens: [firstScreen === 'q:1' ? MANIFEST.screens[1] : MANIFEST.screens[0]],
        scenario: [{ screen_ref: firstScreen, expected_verdict: 'correct' }],
      });
      return auditRun(m, runRecord, c.snapshot());
    };
    expect(codes(build('q:1'))).toContain('pre-entry-illegal');
    expect(codes(build('n:1'))).not.toContain('pre-entry-illegal');
  });

  test('redaction canary: reports built from a poisoned journal never leak the values (§8)', () => {
    const SENTINEL = 'CANARY_SECRET_42';
    const reports: string[] = [];

    const wrongValue = buildRun({ gradedValue: SENTINEL });
    reports.push(formatViolations(auditRun(manifest(), wrongValue.runRecord, wrongValue.snapshot)));

    const contaminated = buildRun({
      gradedExtraParts: [{ path: 'c:1|stage.smuggled', value: SENTINEL }],
    });
    reports.push(
      formatViolations(auditRun(manifest(), contaminated.runRecord, contaminated.snapshot)),
    );

    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: SENTINEL }]);
    const checking = c.ingestRequest({
      method: 'PUT',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-q2`,
      postData: JSON.stringify({ partInputs: [] }),
    }) as number;
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: `${SENTINEL}-mutated` }]);
    c.ingestResponse(checking, 200);
    c.ingestResponseBody(
      checking,
      JSON.stringify({ actions: { correct: true, results: [event(true, [navTo('next')])] } }),
    );
    c.beginSeal();
    c.finishSeal();
    const snap = c.snapshot();
    reports.push(
      formatViolations(
        auditCrossScreenReceipt(
          snap,
          {
            stepIndex: 1,
            screenId: 'q:2',
            directive: 'cross_screen',
            matcher: 'cross_screen',
            expectations: [
              { part_path: 'q:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
            ],
          },
          [['a-dep']],
          snap.records[checking],
        ),
      ),
    );

    expect(reports.some((r) => r.includes('violation'))).toBe(true);
    for (const report of reports) {
      expect(report).not.toContain(SENTINEL);
    }
  });

  test('production-mirrored operator refusals: NaN, undefined, falsy and partial-numeric inputs', () => {
    // equality.ts:155-170 — a missing or NaN numeric fact never satisfies notEqual
    expect(evaluatePredicate({ op: 'notEqual', value: 32.06 }, undefined)).toBe(false);
    expect(evaluatePredicate({ op: 'notEqual', value: 32.06 }, NaN)).toBe(false);
    expect(evaluatePredicate({ op: 'notEqual', value: 32.06 }, 'abc')).toBe(true);
    // contains.ts:79-96 — an EMPTY submission can never satisfy an exclusion
    expect(evaluatePredicate({ op: 'notContainsAnyOf', value: [1, 2] }, '')).toBe(false);
    expect(evaluatePredicate({ op: 'notContainsAnyOf', value: [1, 2] }, undefined)).toBe(false);
    // ...and its string branch is case-SENSITIVE, unlike containsAnyOf's
    expect(evaluatePredicate({ op: 'notContainsAnyOf', value: ['abc'] }, 'ABC')).toBe(true);
    // engine-default-operators.js:34-48 — validator on parseFloat, comparison on the raw fact
    expect(evaluatePredicate({ op: 'greaterThan', value: 3 }, '5abc')).toBe(false);
    expect(evaluatePredicate({ op: 'greaterThan', value: 3 }, ' 5 ')).toBe(true);
    // contains falsy-input guard is the production `!inputValue`
    expect(evaluatePredicate({ op: 'contains', value: 'x' }, 0)).toBe(false);
    expect(evaluatePredicate({ op: 'containsAnyOf', value: [0] }, ' ')).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-2 witnesses
// ---------------------------------------------------------------------------

test.describe('round-2: cardinality, ordering and inventory', () => {
  test('a CONTENT step never licenses a second evaluation, ack or not (§3.5)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('c:1');
    const first = fireEval(c, 'a-c1', [], {
      correct: true,
      results: [event(true, [feedback()])],
      llm: { text: 'AI feedback forces a feedback plan' },
    });
    const second = fireEval(c, 'a-c1', [], {
      correct: true,
      results: [event(true, [navTo('endOfLesson')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const ackSeq = (c.records()[first].responseSeq as number) + 0.5;
    const runRecord: RunRecord = {
      visits: [{ screenId: 'c:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-c1', resourceId: 1 }],
      permits: [
        { kind: 'check-click', screenId: 'c:1', stepIndex: 0, seq: beforeSeq(c, first) },
        { kind: 'feedback-ack', screenId: 'c:1', stepIndex: 0, seq: ackSeq },
      ],
      receipts: [],
      operationFailures: [],
      plans: [recordedPlanFor(c, first, 0), recordedPlanFor(c, second, 0)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[2]],
      scenario: [{ screen_ref: 'c:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(codes(found)).toContain('evaluation-count');
    expect(codes(found)).toContain('evaluation-no-causal-edge');
  });

  test('a delayed save from an OLDER part attempt cannot resurrect it — fail closed (§3.6)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 1, partGuid: 'pa-1' }]);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 7, partGuid: 'pa-2' }]);
    // observation order cannot prove row order in EITHER direction, so a
    // multi-attempt part refuses instead of ranking — stale state can
    // neither be resurrected NOR silently validated
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 99, partGuid: 'pa-1' }]);
    c.beginSeal();
    c.finishSeal();
    const { state, ambiguousParts } = committedPriorState(c.snapshot(), ['a-dep'], 999);
    expect(ambiguousParts).toEqual(['sim']);
    expect(state.get('q:1|stage.sim.B')).toBeUndefined();
  });

  test('recorded-plan inventory: duplicates, misattribution and unmatched records (§3.5)', () => {
    const duplicated = buildRun();
    duplicated.runRecord.plans!.push({ ...duplicated.runRecord.plans![1] });
    const foundDup = auditRun(manifest(), duplicated.runRecord, duplicated.snapshot);
    expect(
      foundDup.some((v) => v.code === 'plan-divergence' && v.facts.detail === 'duplicate'),
    ).toBe(true);

    const misattributed = buildRun();
    misattributed.runRecord.plans![1].stepIndex = 2; // right seq, wrong step
    const foundMis = auditRun(manifest(), misattributed.runRecord, misattributed.snapshot);
    expect(
      foundMis.some(
        (v) => v.code === 'plan-divergence' && v.facts.detail === 'missing-recorded-plan',
      ),
    ).toBe(true);
    expect(foundMis.some((v) => v.code === 'plan-divergence' && v.facts.detail === 'unused')).toBe(
      true,
    );
  });

  test('a first-step permit stamped before the identity fence is outside its window (§3.4)', () => {
    const { snapshot, runRecord } = buildRun();
    runRecord.permits.push({
      kind: 'feedback-ack',
      screenId: 'n:1',
      stepIndex: 0,
      seq: runRecord.visits[0].entrySeq - 0.5,
    });
    const found = auditRun(manifest(), runRecord, snapshot);
    expect(
      found.some((v) => v.code === 'permit-mismatch' && v.facts.detail === 'outside-window'),
    ).toBe(true);
  });
});

test.describe('round-2: navigation plan evidence and route targets', () => {
  function navFrozenRun(withPlan: boolean, mutate?: (p: { plan: unknown }) => void) {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    const navEval = fireEval(c, 'a-n1', [], {
      correct: true,
      results: [event(true, [navTo('endOfLesson')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const plans = withPlan ? [recordedPlanFor(c, navEval, 0)] : [];
    if (mutate && plans.length) mutate(plans[0] as unknown as { plan: unknown });
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [{ kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: v0.seq + 0.5 }],
      receipts: [],
      operationFailures: [],
      plans,
    };
    const m = manifest({
      screens: [MANIFEST.screens[0]],
      scenario: [{ screen_ref: 'n:1', expected_verdict: 'correct' }],
    });
    return auditRun(m, runRecord, c.snapshot());
  }

  test('navigation evaluations REQUIRE a recorded plan on a full audit (§3.5)', () => {
    const missing = navFrozenRun(false);
    expect(
      missing.some(
        (v) => v.code === 'plan-divergence' && v.facts.detail === 'missing-recorded-plan',
      ),
    ).toBe(true);
    expect(codes(navFrozenRun(true))).toEqual([]);
  });

  test('a diverging recorded navigation plan is a violation', () => {
    const found = navFrozenRun(true, (p) => {
      p.plan = { kind: 'auto-navigate', target: 'next' };
    });
    expect(codes(found)).toContain('plan-divergence');
  });

  test('a non-final navigate plan must target the scenario successor (§3.5)', () => {
    const { snapshot, runRecord } = buildRun();
    // rewrite the graded step's recorded+replayed target to an explicit WRONG screen:
    // rebuild the journal is heavy — instead poison via a fresh two-screen run
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const gradedEval = fireEval(
      c,
      'a-q1',
      [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
      { correct: true, results: [event(true, [navTo('x:9')])] },
    );
    const v1 = c.issueFence('c:1');
    const contentEval = fireEval(c, 'a-c1', [], {
      correct: true,
      results: [event(true, [navTo('endOfLesson')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const two: RunRecord = {
      visits: [
        { screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 },
        { screenId: 'c:1', entrySeq: v1.seq, renderedAttemptGuid: 'a-c1', resourceId: 2 },
      ],
      permits: [
        { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
        { kind: 'check-click', screenId: 'c:1', stepIndex: 1, seq: beforeSeq(c, contentEval) },
      ],
      receipts: [{ ...RECEIPT_Q1, stepIndex: 0 }],
      operationFailures: [],
      plans: [recordedPlanFor(c, gradedEval, 0), recordedPlanFor(c, contentEval, 1)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1], MANIFEST.screens[2]],
      scenario: [
        { screen_ref: 'q:1', expected_verdict: 'correct' },
        { screen_ref: 'c:1', expected_verdict: 'correct' },
      ],
    });
    const found = auditRun(m, two, c.snapshot());
    expect(
      found.some(
        (v) => v.code === 'obligation-unfulfilled' && v.facts.detail === 'wrong-successor-target',
      ),
    ).toBe(true);
    expect(codes(auditRun(manifest(), runRecord, snapshot))).toEqual([]);
  });

  test('every disqualifying final-step target: prev, first, last, explicit id (§8)', () => {
    for (const target of ['prev', 'first', 'last', 'q:7']) {
      const c = new AdaptiveJournalCore(() => 1_000);
      c.setRunCorrelation(CORR);
      const v0 = c.issueFence('q:1');
      const gradedEval = fireEval(
        c,
        'a-q1',
        [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
        { correct: true, results: [event(true, [navTo(target)])] },
      );
      c.noteLessonEnd();
      acceptFinalization(c);
      c.markFrozenAccepted();
      const runRecord: RunRecord = {
        visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
        permits: [
          { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
        ],
        receipts: [{ ...RECEIPT_Q1, stepIndex: 0 }],
        operationFailures: [],
        plans: [recordedPlanFor(c, gradedEval, 0)],
      };
      const m = manifest({
        screens: [MANIFEST.screens[1]],
        scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
      });
      const found = auditRun(m, runRecord, c.snapshot());
      expect(
        found.some(
          (v) => v.code === 'obligation-unfulfilled' && v.facts.detail === 'target-not-next',
        ),
        `target ${target}`,
      ).toBe(true);
    }
  });

  test('a rotation whose mint postdates the second check is not the measured rotation (§3.4)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    fireEval(c, 'a-n1', [], { correct: false, results: [event(false, [feedback()])] });
    fireEval(c, 'a-n1b', [], { correct: true, results: [event(true, [navTo('next')])] });
    fireMint(c, 'a-n1', 'a-n1b'); // too late — after the second check used it
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [{ kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: v0.seq + 0.5 }],
      receipts: [],
      operationFailures: [],
      plans: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[0]],
      scenario: [{ screen_ref: 'n:1', expected_verdict: 'correct' }],
    });
    expect(codes(auditRun(m, runRecord, c.snapshot()))).toContain('navigation-sequence');
  });
});

test.describe('round-2: matrix rows through auditRun', () => {
  test('an LLM-feedback plan carries a real ack obligation through auditRun (§8)', () => {
    const build = (withAck: boolean) => {
      const c = new AdaptiveJournalCore(() => 1_000);
      c.setRunCorrelation(CORR);
      const v0 = c.issueFence('q:1');
      const gradedEval = fireEval(
        c,
        'a-q1',
        [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
        {
          correct: true,
          results: [event(true, [navTo('next')])],
          llm: { text: 'AI says: well reasoned' },
        },
      );
      c.noteLessonEnd();
      acceptFinalization(c);
      c.markFrozenAccepted();
      const runRecord: RunRecord = {
        visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
        permits: [
          { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
          ...(withAck
            ? [
                {
                  kind: 'feedback-ack' as const,
                  screenId: 'q:1',
                  stepIndex: 0,
                  seq: (c.records()[gradedEval].responseSeq as number) + 0.5,
                },
              ]
            : []),
        ],
        receipts: [{ ...RECEIPT_Q1, stepIndex: 0 }],
        operationFailures: [],
        plans: [recordedPlanFor(c, gradedEval, 0)],
      };
      const m = manifest({
        screens: [MANIFEST.screens[1]],
        scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
      });
      return auditRun(m, runRecord, c.snapshot());
    };
    expect(
      build(false).some((v) => v.code === 'obligation-unfulfilled' && v.facts.detail === 'no-ack'),
    ).toBe(true);
    expect(codes(build(true))).toEqual([]);
  });

  test('wrong-lineage prior state is caught THROUGH auditRun: alien saves prove nothing (§8)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('s:1');
    const contentEval = fireEval(c, 'a-s1', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    // the state the rule needs was saved under an attempt OUTSIDE the
    // dependency's lineage — the committed prior state stays empty
    fireSave(c, 'a-alien', [{ path: 's:1|stage.sim.Correct', value: true }]);
    const v1 = c.issueFence('q:2');
    const checkingEval = fireEval(c, 'a-q2', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const m: AdaptiveManifest = {
      screens: [
        { id: 's:1', resource_id: 301, role: 'content' },
        {
          id: 'q:2',
          resource_id: 302,
          role: 'graded',
          dependencies: ['s:1'],
          expectations: [
            { part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
          ],
        },
      ],
      scenario: [
        { screen_ref: 's:1', expected_verdict: 'correct' },
        { screen_ref: 'q:2', expected_verdict: 'correct' },
      ],
    };
    const runRecord: RunRecord = {
      visits: [
        { screenId: 's:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-s1', resourceId: 1 },
        { screenId: 'q:2', entrySeq: v1.seq, renderedAttemptGuid: 'a-q2', resourceId: 2 },
      ],
      permits: [
        { kind: 'check-click', screenId: 's:1', stepIndex: 0, seq: beforeSeq(c, contentEval) },
        { kind: 'check-click', screenId: 'q:2', stepIndex: 1, seq: beforeSeq(c, checkingEval) },
      ],
      receipts: [
        {
          stepIndex: 1,
          screenId: 'q:2',
          directive: 'cross_screen',
          matcher: 'cross_screen',
          expectations: [
            { part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
          ],
        },
      ],
      operationFailures: [],
      plans: [recordedPlanFor(c, contentEval, 0), recordedPlanFor(c, checkingEval, 1)],
    };
    expect(codes(auditRun(m, runRecord, c.snapshot()))).toContain('payload-mismatch');
  });

  test('§3.2 matrix: a CLOSED sealed window still draws absence conclusions; seal_incomplete never does', () => {
    const build = (leaveUnterminated: boolean) => {
      const c = new AdaptiveJournalCore(() => 1_000);
      c.setRunCorrelation(CORR);
      const v0 = c.issueFence('q:1');
      const gradedEval = fireEval(
        c,
        'a-q1',
        [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
        { correct: true, results: [event(true, [navTo('next')])] },
      );
      const v1 = c.issueFence('c:1');
      if (leaveUnterminated) {
        c.ingestRequest({
          method: 'PUT',
          url: `${ORIGIN}/state/course/s1/activity_attempt/a-c1`,
          postData: JSON.stringify({ partInputs: [] }),
        });
      }
      c.beginSeal();
      c.finishSeal();
      const runRecord: RunRecord = {
        visits: [
          { screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 },
          { screenId: 'c:1', entrySeq: v1.seq, renderedAttemptGuid: 'a-c1', resourceId: 2 },
        ],
        permits: [
          { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
        ],
        receipts: [], // graded window 0 has NO receipt
        operationFailures: [],
        plans: [recordedPlanFor(c, gradedEval, 0)],
      };
      const m = manifest({
        screens: [MANIFEST.screens[1], MANIFEST.screens[2]],
        scenario: [
          { screen_ref: 'q:1', expected_verdict: 'correct' },
          { screen_ref: 'c:1', expected_verdict: 'correct' },
        ],
      });
      return {
        found: auditRun(m, runRecord, c.snapshot()),
        sealIncomplete: c.snapshot().sealIncomplete,
      };
    };
    const settled = build(false);
    expect(settled.sealIncomplete).toBe(false);
    expect(codes(settled.found)).toContain('receipt-missing'); // closed window: absence allowed
    const incomplete = build(true);
    expect(incomplete.sealIncomplete).toBe(true);
    expect(codes(incomplete.found)).not.toContain('receipt-missing'); // journal-wide positive-only
  });

  test('production contains refuses non-string scalar inputs; notContains inherits the negation (§3.8)', () => {
    expect(evaluatePredicate({ op: 'contains', value: '5' }, 5)).toBe(false);
    expect(evaluatePredicate({ op: 'contains', value: ['5'] }, 55)).toBe(false);
    expect(evaluatePredicate({ op: 'notContains', value: '5' }, 5)).toBe(true);
    expect(evaluatePredicate({ op: 'contains', value: 'asal' }, 'Basalt')).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-3 witnesses
// ---------------------------------------------------------------------------

test.describe('round-3: settlement, domain sweep and remaining §8 rows', () => {
  test('a closed sealed window with a FAILED candidate is settled — absence conclusions apply (§3.2)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const failedPut = c.ingestRequest({
      method: 'PUT',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-q1`,
      postData: JSON.stringify({ partInputs: [] }),
    }) as number;
    c.ingestRequestFailed(failedPut);
    const v1 = c.issueFence('c:1');
    c.beginSeal();
    c.finishSeal();
    expect(c.snapshot().sealIncomplete).toBe(false);
    const runRecord: RunRecord = {
      visits: [
        { screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 },
        { screenId: 'c:1', entrySeq: v1.seq, renderedAttemptGuid: 'a-c1', resourceId: 2 },
      ],
      permits: [],
      receipts: [], // graded window 0: no receipt
      operationFailures: [],
      plans: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1], MANIFEST.screens[2]],
      scenario: [
        { screen_ref: 'q:1', expected_verdict: 'correct' },
        { screen_ref: 'c:1', expected_verdict: 'correct' },
      ],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    // the failure is positive evidence AND the closed window still audits fully
    expect(codes(found)).toContain('unresolved-candidate-owned');
    expect(codes(found)).toContain('receipt-missing');
  });

  test('permits, plans and receipts naming a step with no visit are violations (§3.5 domain)', () => {
    const { snapshot, runRecord } = buildRun();
    runRecord.permits.push({ kind: 'check-click', screenId: 'x:9', stepIndex: 9, seq: 500 });
    runRecord.plans!.push({
      stepIndex: 9,
      evaluationSeq: 501,
      plan: { kind: 'terminal' } as never,
    });
    runRecord.receipts.push({ ...RECEIPT_Q1, stepIndex: 9 });
    const found = auditRun(manifest(), runRecord, snapshot);
    expect(
      found.some((v) => v.code === 'permit-mismatch' && v.facts.detail === 'beyond-route'),
    ).toBe(true);
    expect(
      found.some((v) => v.code === 'plan-divergence' && v.facts.detail === 'beyond-route'),
    ).toBe(true);
    expect(
      found.some((v) => v.code === 'receipt-mismatch' && v.facts.detail === 'beyond-route'),
    ).toBe(true);
  });

  test('a duplicate local operation id fails manifest validation (§8)', () => {
    const dup = manifest();
    dup.screens[1].operations!.push({ ...dup.screens[1].operations![0] });
    expect(() => validateAdaptiveManifest(dup)).toThrow(/duplicate operation id "a1"/);
  });

  test('a PRE-ENTRY split rotation cannot bypass the sequence rule (§8)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    // first half of the rotation fires BEFORE the identity fence; the second
    // half after it; no causal mint anywhere — one whole-sequence judgement
    fireEval(c, 'a-n1', [], { correct: false, results: [event(false, [feedback()])] });
    const v0 = c.issueFence('n:1');
    fireEval(c, 'a-n1b', [], { correct: true, results: [event(true, [navTo('next')])] });
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [{ kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: v0.seq + 0.5 }],
      receipts: [],
      operationFailures: [],
      plans: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[0]],
      scenario: [{ screen_ref: 'n:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(codes(found)).toContain('navigation-sequence');
    expect(codes(found)).toContain('lineage');
  });

  test('isEqual port quirks pinned: array-fact branch, numeric-fact parsing, encoded-array facts', () => {
    // native-array fact vs string-typed numbers: parseNumString aligns both sides
    expect(evaluatePredicate({ op: 'equal', value: [2, 5] }, ['5', '2'])).toBe(true);
    // number condition wraps to a one-element array against an array fact
    expect(evaluatePredicate({ op: 'equal', value: 5 }, [5])).toBe(true);
    // a STRING-ENCODED array fact takes the scalar branches — production quirk
    expect(evaluatePredicate({ op: 'equal', value: [1, 2] }, '[1,2]')).toBe(false);
    // numeric FACT parses a string condition (equality.ts:69)
    expect(evaluatePredicate({ op: 'equal', value: '3.0' }, 3)).toBe(true);
    // operator ERROR shapes stay fail-closed under BOTH polarities
    expect(evaluatePredicate({ op: 'contains', value: ['x'] }, 5)).toBe(false);
    expect(evaluatePredicate({ op: 'notContains', value: ['x'] }, 5)).toBe(false);
    // ...while the legal string branch still negates normally
    expect(evaluatePredicate({ op: 'notContains', value: 'lava' }, 'magma')).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-4 witnesses
// ---------------------------------------------------------------------------

test.describe('round-4: rotation plan legality, receipt inventory, operator ports', () => {
  test('a rotation whose first plan is `none` is illegal — feedback is the only legal first half (§3.4)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    fireEval(c, 'a-n1', [], { correct: false, results: [event(false, [])] }); // plan: none
    fireMint(c, 'a-n1', 'a-n1b');
    fireEval(c, 'a-n1b', [], { correct: true, results: [event(true, [navTo('next')])] });
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [{ kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: v0.seq + 0.5 }],
      receipts: [],
      operationFailures: [],
      plans: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[0]],
      scenario: [{ screen_ref: 'n:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(codes(found)).toContain('navigation-sequence');
    expect(codes(found)).toContain('plan-illegal');
  });

  test('receipt inventory: duplicates on a graded step and receipts on non-graded steps (§3.5)', () => {
    const duplicated = buildRun();
    duplicated.runRecord.receipts.push({ ...RECEIPT_Q1 });
    const foundDup = auditRun(manifest(), duplicated.runRecord, duplicated.snapshot);
    expect(
      foundDup.some((v) => v.code === 'receipt-mismatch' && v.facts.detail === 'duplicate'),
    ).toBe(true);

    const wrongRole = buildRun();
    wrongRole.runRecord.receipts.push({ ...RECEIPT_Q1, stepIndex: 2, screenId: 'c:1' });
    const foundRole = auditRun(manifest(), wrongRole.runRecord, wrongRole.snapshot);
    expect(
      foundRole.some((v) => v.code === 'receipt-mismatch' && v.facts.detail === 'wrong-role'),
    ).toBe(true);
  });

  test('parseNumString and parseBoolean port rows: eligibility vs conversion, the on spelling, null facts', () => {
    // Number() is eligibility, parseFloat() converts: '0x10' → 0, never 16
    expect(evaluatePredicate({ op: 'equal', value: [0] }, ['0x10'])).toBe(true);
    // parseBoolean accepts 'on' (common.ts:73)
    expect(evaluatePredicate({ op: 'equal', value: 'true' }, 'on')).toBe(true);
    // a null fact THROWS in production's boolean branches — typed operator
    // error here, fail-closed under BOTH polarities
    expect(evaluatePredicate({ op: 'equal', value: true }, null)).toBe(false);
    expect(evaluatePredicate({ op: 'notEqual', value: true }, null)).toBe(false);
    // ...while a null fact against a STRING condition legally compares false
    expect(evaluatePredicate({ op: 'notEqual', value: 'x' }, null)).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-5 witnesses
// ---------------------------------------------------------------------------

test.describe('round-5: barrier commit order, unconditional coverage, permit allowlist', () => {
  test('a save still in flight at click-time cannot satisfy the barrier (§3.5)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const readbackSeq = c.issueFence('q:1').seq;
    // the save's REQUEST starts inside the window, but its response commits
    // only after the check-click
    const save = c.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-q1/active`,
      postData: JSON.stringify({
        partInputs: [
          {
            attemptGuid: 'part-a-q1',
            response: { k0: { path: 'q:1|stage.widget.state', value: 'ready' } },
          },
        ],
      }),
    }) as number;
    const clickSeq = (c.records()[save].requestSeq as number) + 0.5;
    c.ingestResponse(save, 200);
    c.ingestResponseBody(save, JSON.stringify({ type: 'success' }));
    const gradedEval = fireEval(
      c,
      'a-q1',
      [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
      { correct: true, results: [event(true, [navTo('endOfLesson')])] },
    );
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
      permits: [{ kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: clickSeq }],
      receipts: [
        {
          ...RECEIPT_Q1,
          stepIndex: 0,
          savedBarrierPrefixes: ['q:1|stage.widget'],
          readbackCompletedSeq: readbackSeq,
        },
      ],
      operationFailures: [],
      plans: [recordedPlanFor(c, gradedEval, 0)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1]],
      scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(codes(found)).toContain('saved-barrier');
  });

  test('a SAME-SCREEN rule reference without a covering expectation fails the build (§3.6b)', () => {
    const m = manifest();
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({
          rule_prior_state_refs: { 'n:1': [], 'q:1': ['q:1|stage.slider.value'], 'c:1': [] },
        }),
        m,
      ),
    ).toThrow(/prior state "q:1\|stage.slider.value" with no covering/);
  });

  test('permit role allowlist binds both directions; widget-button duplicates are violations (§3.4)', () => {
    const { snapshot, runRecord } = buildRun();
    runRecord.permits.push(
      // check-click on the NAVIGATION step — the driver performs none there
      {
        kind: 'check-click',
        screenId: 'n:1',
        stepIndex: 0,
        seq: runRecord.visits[0].entrySeq + 0.7,
      },
      // second widget-button on the same navigation step
      {
        kind: 'widget-button',
        screenId: 'n:1',
        stepIndex: 0,
        seq: runRecord.visits[0].entrySeq + 0.8,
      },
    );
    const found = auditRun(manifest(), runRecord, snapshot);
    expect(
      found.some(
        (v) =>
          v.code === 'permit-mismatch' &&
          v.facts.detail === 'wrong-role' &&
          v.facts.permitKind === 'check-click',
      ),
    ).toBe(true);
    expect(
      found.some(
        (v) =>
          v.code === 'permit-mismatch' &&
          v.facts.detail === 'duplicate' &&
          v.facts.permitKind === 'widget-button',
      ),
    ).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-7 witnesses
// ---------------------------------------------------------------------------

test.describe('round-7: terminal commit proofs, causal tips, permit and attribution evidence', () => {
  test('a save with 2xx headers that then FAILS proves nothing — barrier, prior state, and reported (§3.5)', () => {
    // barrier path
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('q:1');
    const readbackSeq = c.issueFence('q:1').seq;
    const save = c.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-q1/active`,
      postData: JSON.stringify({
        partInputs: [
          {
            attemptGuid: 'part-a-q1',
            response: { k0: { path: 'q:1|stage.widget.state', value: 'ready' } },
          },
        ],
      }),
    }) as number;
    c.ingestResponse(save, 200); // headers seen...
    c.ingestRequestFailed(save); // ...then the request dies before the body
    const gradedEval = fireEval(
      c,
      'a-q1',
      [{ path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' }],
      { correct: true, results: [event(true, [navTo('endOfLesson')])] },
    );
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'q:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-q1', resourceId: 1 }],
      permits: [
        { kind: 'check-click', screenId: 'q:1', stepIndex: 0, seq: beforeSeq(c, gradedEval) },
      ],
      receipts: [
        {
          ...RECEIPT_Q1,
          stepIndex: 0,
          savedBarrierPrefixes: ['q:1|stage.widget'],
          readbackCompletedSeq: readbackSeq,
        },
      ],
      operationFailures: [],
      plans: [recordedPlanFor(c, gradedEval, 0)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[1]],
      scenario: [{ screen_ref: 'q:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(codes(found)).toContain('saved-barrier'); // the failed save satisfies nothing
    expect(codes(found)).toContain('request-failed'); // and is REPORTED (§3.5 table)

    // prior-state path: the only save of the dependency fails after headers
    const c2 = new AdaptiveJournalCore(() => 1_000);
    const dep = c2.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-dep/active`,
      postData: JSON.stringify({
        partInputs: [
          {
            attemptGuid: 'part-a-dep',
            response: { k0: { path: 'q:1|stage.sim.Correct', value: true } },
          },
        ],
      }),
    }) as number;
    c2.ingestResponse(dep, 200);
    c2.ingestRequestFailed(dep); // headers, no body — terminal 'failed', status 200
    c2.beginSeal();
    c2.finishSeal();
    const { state } = committedPriorState(c2.snapshot(), ['a-dep'], 999);
    expect(state.get('q:1|stage.sim.Correct')).toBeUndefined();
  });

  test('sibling attempt mints FORK the lineage — cross-screen matching fails closed (§3.6)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('s:1');
    const contentEval = fireEval(c, 'a-s1', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    fireSave(c, 'a-s1', [{ path: 's:1|stage.sim.Correct', value: true }]);
    fireMint(c, 'a-s1', 'a-x');
    fireMint(c, 'a-s1', 'a-y'); // sibling — response order cannot prove row order
    const v1 = c.issueFence('q:2');
    const checkingEval = fireEval(c, 'a-q2', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const m: AdaptiveManifest = {
      screens: [
        { id: 's:1', resource_id: 301, role: 'content' },
        {
          id: 'q:2',
          resource_id: 302,
          role: 'graded',
          dependencies: ['s:1'],
          expectations: [
            { part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
          ],
        },
      ],
      scenario: [
        { screen_ref: 's:1', expected_verdict: 'correct' },
        { screen_ref: 'q:2', expected_verdict: 'correct' },
      ],
    };
    const runRecord: RunRecord = {
      visits: [
        { screenId: 's:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-s1', resourceId: 1 },
        { screenId: 'q:2', entrySeq: v1.seq, renderedAttemptGuid: 'a-q2', resourceId: 2 },
      ],
      permits: [
        { kind: 'check-click', screenId: 's:1', stepIndex: 0, seq: beforeSeq(c, contentEval) },
        { kind: 'check-click', screenId: 'q:2', stepIndex: 1, seq: beforeSeq(c, checkingEval) },
      ],
      receipts: [
        {
          stepIndex: 1,
          screenId: 'q:2',
          directive: 'cross_screen',
          matcher: 'cross_screen',
          expectations: [
            { part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
          ],
        },
      ],
      operationFailures: [],
      plans: [recordedPlanFor(c, contentEval, 0), recordedPlanFor(c, checkingEval, 1)],
    };
    const found = auditRun(m, runRecord, c.snapshot());
    expect(
      found.some(
        (v) => v.code === 'payload-mismatch' && v.facts.detail === 'ambiguous-attempt-order',
      ),
    ).toBe(true);
  });

  test('a fully audited navigation window REQUIRES its widget-button permit (§3.4)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    const navEval = fireEval(c, 'a-n1', [], {
      correct: true,
      results: [event(true, [navTo('endOfLesson')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [], // the in-widget action was never proven
      receipts: [],
      operationFailures: [],
      plans: [recordedPlanFor(c, navEval, 0)],
    };
    const m = manifest({
      screens: [MANIFEST.screens[0]],
      scenario: [{ screen_ref: 'n:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(
      found.some(
        (v) =>
          v.code === 'permit-mismatch' &&
          v.facts.detail === 'missing' &&
          v.facts.permitKind === 'widget-button',
      ),
    ).toBe(true);
  });

  test('operation-failure attribution is validated: domain, nullability, derived screens (§3.2)', () => {
    const { snapshot, runRecord } = buildRun();
    runRecord.operationFailures = [
      { kind: 'answer-failed', screenId: 'q:1', expectedStepIndex: 9 }, // beyond scenario
      { kind: 'identity-unresolved', screenId: 'q:1', expectedStepIndex: 1 }, // must be null
      { kind: 'readback-failed', screenId: null, expectedStepIndex: 1 }, // must be resolved
    ];
    const found = auditRun(manifest(), runRecord, snapshot);
    const ops = found.filter((v) => v.code === 'operation-failure');
    expect(ops.some((v) => v.facts.detail === 'beyond-route')).toBe(true);
    // 3: the null-screen resolved failure, the non-null identity-unresolved,
    // AND the beyond-domain resolved failure (no visit can support it)
    expect(ops.filter((v) => v.facts.detail === 'screen-mismatch').length).toBe(3);
    // identity-unresolved reports the screen DERIVED from the scenario step
    expect(
      ops.some((v) => v.facts.failureKind === 'identity-unresolved' && v.screenId === 'q:1'),
    ).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-8 witnesses
// ---------------------------------------------------------------------------

test.describe('round-8: PUT commits, presence-only counts, exact failure attribution', () => {
  test('an evaluation-only dependency commits state through its PUT — no save required (§3.6)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('s:1');
    // the dependency's own evaluation PUT carries and PERSISTS its state
    const contentEval = fireEval(c, 'a-s1', [{ path: 's:1|stage.sim.Correct', value: true }], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    const v1 = c.issueFence('q:2');
    const checkingEval = fireEval(c, 'a-q2', [], {
      correct: true,
      results: [event(true, [navTo('next')])],
    });
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const m: AdaptiveManifest = {
      screens: [
        { id: 's:1', resource_id: 301, role: 'content' },
        {
          id: 'q:2',
          resource_id: 302,
          role: 'graded',
          dependencies: ['s:1'],
          expectations: [
            { part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
          ],
        },
      ],
      scenario: [
        { screen_ref: 's:1', expected_verdict: 'correct' },
        { screen_ref: 'q:2', expected_verdict: 'correct' },
      ],
    };
    const runRecord: RunRecord = {
      visits: [
        { screenId: 's:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-s1', resourceId: 1 },
        { screenId: 'q:2', entrySeq: v1.seq, renderedAttemptGuid: 'a-q2', resourceId: 2 },
      ],
      permits: [
        { kind: 'check-click', screenId: 's:1', stepIndex: 0, seq: beforeSeq(c, contentEval) },
        { kind: 'check-click', screenId: 'q:2', stepIndex: 1, seq: beforeSeq(c, checkingEval) },
      ],
      receipts: [
        {
          stepIndex: 1,
          screenId: 'q:2',
          directive: 'cross_screen',
          matcher: 'cross_screen',
          expectations: [
            { part_path: 's:1|stage.sim.Correct', predicate: { op: 'equal', value: true } },
          ],
        },
      ],
      operationFailures: [],
      plans: [recordedPlanFor(c, contentEval, 0), recordedPlanFor(c, checkingEval, 1)],
    };
    expect(codes(auditRun(m, runRecord, c.snapshot()))).toEqual([]);
  });

  test('a later PUT commit REPLACES an earlier PATCH state; overlapping commits are ambiguous (§3.6)', () => {
    // sequential: save true, then the evaluation PUT commits false — false wins
    const c = new AdaptiveJournalCore(() => 1_000);
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: true }]);
    fireEval(c, 'a-dep', [{ path: 'q:1|stage.sim.Correct', value: false }], {
      correct: false,
      results: [event(false, [feedback()])],
    });
    c.beginSeal();
    c.finishSeal();
    const sequential = committedPriorState(c.snapshot(), ['a-dep'], 999);
    expect(sequential.ambiguousParts).toEqual([]);
    expect(sequential.state.get('q:1|stage.sim.Correct')).toBe(false);

    // overlapping: two in-flight commits to one part — server order opaque
    const c2 = new AdaptiveJournalCore(() => 1_000);
    const first = c2.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-dep/active`,
      postData: JSON.stringify({
        partInputs: [
          {
            attemptGuid: 'part-a-dep',
            response: { k0: { path: 'q:1|stage.sim.Correct', value: true } },
          },
        ],
      }),
    }) as number;
    const second = c2.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-dep/active`,
      postData: JSON.stringify({
        partInputs: [
          {
            attemptGuid: 'part-a-dep',
            response: { k0: { path: 'q:1|stage.sim.Correct', value: false } },
          },
        ],
      }),
    }) as number;
    c2.ingestResponse(first, 200);
    c2.ingestResponseBody(first, JSON.stringify({ type: 'success' }));
    c2.ingestResponse(second, 200);
    c2.ingestResponseBody(second, JSON.stringify({ type: 'success' }));
    c2.beginSeal();
    c2.finishSeal();
    const overlapping = committedPriorState(c2.snapshot(), ['a-dep'], 999);
    expect(overlapping.ambiguousParts).toEqual(['sim']);
    expect(overlapping.state.get('q:1|stage.sim.Correct')).toBeUndefined();
  });

  test('presence-only prefix expectations count DISTINCT paths against min_count (R4-SF3)', () => {
    const presence = { part_path_prefix: 'q:1|stage.fib', min_count: 2 };
    const m = manifest();
    m.screens[1].expectations = [presence];
    const receipt: StepReceipt[] = [{ ...RECEIPT_Q1, expectations: [presence] }];

    const duplicated = buildRun({
      receipts: receipt,
      gradedValue: undefined,
      gradedExtraParts: [
        { path: 'q:1|stage.fib.blank1', value: 'x' },
        { path: 'q:1|stage.fib.blank1', value: 'x' },
      ],
    });
    expect(codes(auditRun(m, duplicated.runRecord, duplicated.snapshot))).toContain(
      'payload-mismatch',
    );

    const distinct = buildRun({
      receipts: receipt,
      gradedExtraParts: [
        { path: 'q:1|stage.fib.blank1', value: 'x' },
        { path: 'q:1|stage.fib.blank2', value: 'y' },
      ],
    });
    expect(codes(auditRun(m, distinct.runRecord, distinct.snapshot))).toEqual([]);
  });

  test('a resolved failure naming a VALID screen of another step is contradictory (§3.2)', () => {
    const { snapshot, runRecord } = buildRun();
    runRecord.operationFailures = [
      { kind: 'answer-failed', screenId: 'c:1', expectedStepIndex: 1 }, // valid screen, wrong step
    ];
    const found = auditRun(manifest(), runRecord, snapshot);
    expect(
      found.some(
        (v) =>
          v.code === 'operation-failure' &&
          v.facts.detail === 'screen-mismatch' &&
          v.facts.otherScreenId === 'c:1',
      ),
    ).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-9 witnesses
// ---------------------------------------------------------------------------

test.describe('round-9: schema boundary, visit-anchored attribution, complete permit accounting', () => {
  test('a non-boolean combine_feedback cannot reach planning (§3.8)', () => {
    const bad = manifest();
    (bad.screens[1] as { combine_feedback?: unknown }).combine_feedback = 'yes';
    expect(() => validateAdaptiveManifest(bad)).toThrow(/combine_feedback must be a boolean/);
    const good = manifest();
    good.screens[1].combine_feedback = true;
    expect(() => validateAdaptiveManifest(good)).not.toThrow();
  });

  test('resolved failures anchor to the OBSERVED visit, not the scenario (§3.2)', () => {
    // route diverged: the visit at step 1 is q:1, the reordered scenario
    // declares c:1 there — naming the observed screen is NOT contradictory,
    // naming the scenario screen IS
    const reordered = manifest();
    reordered.scenario = [reordered.scenario[0], reordered.scenario[2], reordered.scenario[1]];
    const observed = buildRun();
    observed.runRecord.operationFailures = [
      { kind: 'answer-failed', screenId: 'q:1', expectedStepIndex: 1 },
    ];
    const foundObserved = auditRun(reordered, observed.runRecord, observed.snapshot);
    expect(
      foundObserved.some(
        (v) => v.code === 'operation-failure' && v.facts.detail === 'screen-mismatch',
      ),
    ).toBe(false);

    const claimed = buildRun();
    claimed.runRecord.operationFailures = [
      { kind: 'answer-failed', screenId: 'c:1', expectedStepIndex: 1 },
    ];
    const foundClaimed = auditRun(reordered, claimed.runRecord, claimed.snapshot);
    expect(
      foundClaimed.some(
        (v) => v.code === 'operation-failure' && v.facts.detail === 'screen-mismatch',
      ),
    ).toBe(true);
  });

  test('a resolved failure for an in-scenario step with NO visit is contradictory (§3.2)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [],
      receipts: [],
      operationFailures: [{ kind: 'answer-failed', screenId: 'q:1', expectedStepIndex: 1 }],
      plans: [],
    };
    const found = auditRun(manifest(), runRecord, c.snapshot());
    expect(
      found.some((v) => v.code === 'operation-failure' && v.facts.detail === 'screen-mismatch'),
    ).toBe(true);
  });

  test('a stray feedback-ack with NO usable first evaluation is unused (§3.4)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('c:1');
    c.noteLessonEnd();
    acceptFinalization(c);
    c.markFrozenAccepted();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'c:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-c1', resourceId: 1 }],
      permits: [{ kind: 'feedback-ack', screenId: 'c:1', stepIndex: 0, seq: v0.seq + 0.5 }],
      receipts: [],
      operationFailures: [],
      plans: [],
    };
    const m = manifest({
      screens: [MANIFEST.screens[2]],
      scenario: [{ screen_ref: 'c:1', expected_verdict: 'correct' }],
    });
    const found = auditRun(m, runRecord, c.snapshot());
    expect(
      found.some(
        (v) =>
          v.code === 'permit-mismatch' &&
          v.facts.detail === 'unused' &&
          v.facts.permitKind === 'feedback-ack',
      ),
    ).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// checkpoint A round-10 witnesses
// ---------------------------------------------------------------------------

test.describe('round-10: archive identity, seal sentinel, stability keys, schema keys', () => {
  test('a screen resource_id contradicting the archive fails the build (§3.8)', () => {
    const m = manifest();
    expect(() =>
      validateRouteCoverage(
        ARCHIVE_FACTS({ resource_ids: { 'n:1': 101, 'q:1': 999, 'c:1': 103 } }),
        m,
      ),
    ).toThrow(/declares resource_id 102, the archive proves 999/);

    const missing = ARCHIVE_FACTS();
    delete (missing.resource_ids as Record<string, number>)['q:1'];
    expect(() => validateRouteCoverage(missing, manifest())).toThrow(
      /no resource_ids entry for screen "q:1"/,
    );

    const extra = ARCHIVE_FACTS();
    (extra.resource_ids as Record<string, number>)['ghost:9'] = 900;
    expect(() => validateRouteCoverage(extra, manifest())).toThrow(
      /resource_ids names "ghost:9"/,
    );
  });

  test('a sealed snapshot with NO failure evidence carries the §3.2 sentinel', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    const v0 = c.issueFence('n:1');
    c.beginSeal();
    c.finishSeal();
    const runRecord: RunRecord = {
      visits: [{ screenId: 'n:1', entrySeq: v0.seq, renderedAttemptGuid: 'a-n1', resourceId: 1 }],
      permits: [{ kind: 'widget-button', screenId: 'n:1', stepIndex: 0, seq: v0.seq + 0.5 }],
      receipts: [],
      operationFailures: [], // the wrapper failed to stamp anything
      plans: [],
    };
    const found = auditRun(manifest(), runRecord, c.snapshot());
    expect(codes(found)).toEqual(['seal-without-evidence']);

    // ...and any real positive evidence suppresses the sentinel
    const stamped: RunRecord = {
      ...runRecord,
      operationFailures: [
        { kind: 'readiness-timeout', screenId: 'n:1', expectedStepIndex: 0 },
      ],
    };
    expect(codes(auditRun(manifest(), stamped, c.snapshot()))).toEqual(['operation-failure']);
  });

  test('same-cardinality key replacement inside the check window is UNSTABLE (§3.6)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    c.setRunCorrelation(CORR);
    // committed state before the check: path A (with a real value)
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.A', value: 1 }]);
    const checking = c.ingestRequest({
      method: 'PUT',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-q2`,
      postData: JSON.stringify({ partInputs: [] }),
    }) as number;
    // during the window: A is replaced by B — same cardinality, different key
    fireSave(c, 'a-dep', [{ path: 'q:1|stage.sim.B', value: 1 }]);
    c.ingestResponse(checking, 200);
    c.ingestResponseBody(
      checking,
      JSON.stringify({ actions: { correct: true, results: [event(true, [navTo('next')])] } }),
    );
    c.beginSeal();
    c.finishSeal();
    const snap = c.snapshot();
    const found = auditCrossScreenReceipt(
      snap,
      {
        stepIndex: 1,
        screenId: 'q:2',
        directive: 'cross_screen',
        matcher: 'cross_screen',
        // presence-only: exactly the expectation a stale key could satisfy
        expectations: [{ part_path_prefix: 'q:1|stage.sim' }],
      },
      [['a-dep']],
      snap.records[checking],
    );
    expect(
      found.some(
        (v) => v.code === 'payload-mismatch' && v.facts.detail === 'unstable-dependency',
      ),
    ).toBe(true);
  });

  test('path-only entries are never committed state (§3.6)', () => {
    const c = new AdaptiveJournalCore(() => 1_000);
    const save = c.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/a-dep/active`,
      postData: JSON.stringify({
        partInputs: [
          { attemptGuid: 'part-a-dep', response: { k0: { path: 'q:1|stage.sim.A' } } },
        ],
      }),
    }) as number;
    c.ingestResponse(save, 200);
    c.ingestResponseBody(save, JSON.stringify({ type: 'success' }));
    c.beginSeal();
    c.finishSeal();
    const { state } = committedPriorState(c.snapshot(), ['a-dep'], 999);
    expect(state.size).toBe(0);
  });

  test('answer operations with non-string version/mode fail the build (§3.6 registry keys)', () => {
    const badVersion = manifest();
    (badVersion.screens[1].operations![0] as { version?: unknown }).version = 3;
    expect(() => validateAdaptiveManifest(badVersion)).toThrow(/version must be a non-empty string/);

    const badMode = manifest();
    (badMode.screens[1].operations![0] as { mode?: unknown }).mode = '';
    expect(() => validateAdaptiveManifest(badMode)).toThrow(/mode must be a non-empty string/);

    const good = manifest();
    (good.screens[1].operations![0] as { version?: string; mode?: string }).version = 'v3';
    (good.screens[1].operations![0] as { version?: string; mode?: string }).mode = 'B';
    expect(() => validateAdaptiveManifest(good)).not.toThrow();
  });
});
