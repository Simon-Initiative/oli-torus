import { expect, test } from '@playwright/test';
import {
  VisitStamp,
  attribute,
  extractSubmittedPrefixes,
  resolveProvenance,
} from '@tasks/AdaptiveAttribution';
import { AdaptiveJournalCore, JournalSnapshot } from '@tasks/AdaptiveJournal';

/**
 * MER-5865 step 1: attribution matrix (spec §3.3, §8) — half-open ownership
 * windows over real journal fences, pre-entry ownership, attempt-lineage
 * acceptance and rejection (a failed, unparsed, temporally later or
 * un-rooted mint confers nothing), pathless evaluations lineage-checked like
 * any other, prefixes never deciding ownership, and payload provenance by
 * precedence. Snapshots come from a driven journal core, never hand-built —
 * the two modules share one contract.
 */

const ORIGIN = 'https://adaptive-stub.local';

function journal(): AdaptiveJournalCore {
  return new AdaptiveJournalCore(() => 1_000);
}

function visit(c: AdaptiveJournalCore, screenId: string, renderedAttemptGuid: string): VisitStamp {
  return { screenId, entrySeq: c.issueFence(screenId).seq, renderedAttemptGuid };
}

function fireEvaluation(
  c: AdaptiveJournalCore,
  guid: string,
  paths: string[] = [`q:1|stage.dropdown.selectedItem`],
): number {
  const partInputs = paths.map((path, i) => ({
    attemptGuid: `part-${i}`,
    response: { input: { [`k${i}`]: { path, value: 'Basalt' } } },
  }));
  const handle = c.ingestRequest({
    method: 'PUT',
    url: `${ORIGIN}/state/course/s1/activity_attempt/${guid}`,
    postData: JSON.stringify({ partInputs }),
  });
  if (handle === null) throw new Error('journal ignored the evaluation PUT');
  c.ingestResponse(handle, 200);
  c.ingestResponseBody(handle, JSON.stringify({ actions: { correct: true } }));
  return handle;
}

function firePathlessEvaluation(c: AdaptiveJournalCore, guid: string): number {
  const handle = c.ingestRequest({
    method: 'PUT',
    url: `${ORIGIN}/state/course/s1/activity_attempt/${guid}`,
    postData: JSON.stringify({ partInputs: [] }),
  });
  if (handle === null) throw new Error('journal ignored the evaluation PUT');
  c.ingestResponse(handle, 200);
  c.ingestResponseBody(handle, JSON.stringify({ actions: { correct: true } }));
  return handle;
}

function mint(
  c: AdaptiveJournalCore,
  targetGuid: string,
  mintedGuid: string,
  opts: { status?: number; parsed?: boolean; respond?: boolean } = {},
): number {
  const handle = c.ingestRequest({
    method: 'POST',
    url: `${ORIGIN}/state/course/s1/activity_attempt/${targetGuid}`,
    postData: '{}',
  });
  if (handle === null) throw new Error('journal ignored the creation POST');
  if (opts.respond === false) return handle;
  c.ingestResponse(handle, opts.status ?? 200);
  c.ingestResponseBody(
    handle,
    opts.parsed === false
      ? JSON.stringify({})
      : JSON.stringify({ attemptState: { attemptGuid: mintedGuid } }),
  );
  return handle;
}

function completeMint(c: AdaptiveJournalCore, handle: number, mintedGuid: string) {
  c.ingestResponse(handle, 200);
  c.ingestResponseBody(handle, JSON.stringify({ attemptState: { attemptGuid: mintedGuid } }));
}

function sealed(c: AdaptiveJournalCore): JournalSnapshot {
  c.beginSeal();
  c.finishSeal();
  return c.snapshot();
}

test.describe('ownership windows', () => {
  test('half-open windows: each request belongs to the last visit stamped before it', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const first = fireEvaluation(c, 'attempt-1', ['q:1|stage.x']);
    const v2 = visit(c, 'q:2', 'attempt-2');
    const second = fireEvaluation(c, 'attempt-2', ['q:2|stage.x']);

    const { attributed, violations } = attribute(sealed(c), [v1, v2]);
    expect(violations).toEqual([]);
    expect(attributed[first].ownerScreenId).toBe('q:1');
    expect(attributed[first].preEntry).toBe(false);
    expect(attributed[second].ownerScreenId).toBe('q:2');
  });

  test('pre-entry traffic is owned by the FIRST visit and flagged', () => {
    const c = journal();
    const early = fireEvaluation(c, 'attempt-1', ['q:1|stage.x']);
    const v1 = visit(c, 'q:1', 'attempt-1');

    const { attributed } = attribute(sealed(c), [v1]);
    expect(attributed[early].ownerScreenId).toBe('q:1');
    expect(attributed[early].preEntry).toBe(true);
  });

  test('traffic during a transition stays with the old screen — the stamp is the boundary', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const lateFromOld = fireEvaluation(c, 'attempt-1', ['q:1|stage.x']);
    const v2 = visit(c, 'q:2', 'attempt-2');

    const { attributed } = attribute(sealed(c), [v1, v2]);
    expect(attributed[lateFromOld].ownerScreenId).toBe('q:1');
  });

  test('payload prefixes NEVER decide ownership — a foreign prefix stays in its window', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const v2 = visit(c, 'q:2', 'attempt-2');
    // submitted in q:2's window under q:2's rendered attempt, but every part
    // path names q:1 — window + lineage own it, the payload is provenance's
    // problem, not ownership's
    const crossPayload = fireEvaluation(c, 'attempt-2', ['q:1|stage.x', 'q:1|stage.y']);

    const { attributed, violations } = attribute(sealed(c), [v1, v2]);
    expect(violations).toEqual([]);
    expect(attributed[crossPayload].ownerScreenId).toBe('q:2');
    expect(attributed[crossPayload].lineage).toBe('ok');
  });

  test('with no visits nothing is owned and nothing is lineage-judged', () => {
    const c = journal();
    const h = fireEvaluation(c, 'attempt-1');

    const { attributed, violations } = attribute(sealed(c), []);
    expect(attributed[h].ownerScreenId).toBeNull();
    expect(attributed[h].lineage).toBeNull();
    expect(violations).toEqual([]);
  });

  test('visit stamps must cite real fences, for their own screen, in order', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const v2 = visit(c, 'q:2', 'attempt-2');
    const snapshot = sealed(c);

    expect(() => attribute(snapshot, [v2, v1])).toThrow(/out of order/);
    expect(() =>
      attribute(snapshot, [{ screenId: 'q:1', entrySeq: 99, renderedAttemptGuid: 'g' }]),
    ).toThrow(/no journal fence at seq 99/);
    expect(() => attribute(snapshot, [{ ...v1, screenId: 'imposter' }])).toThrow(
      /issued for "q:1"/,
    );
  });
});

test.describe('attempt lineage', () => {
  test('the rendered attempt and a causally minted successor are in lineage', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    fireEvaluation(c, 'attempt-1', ['q:1|stage.x']);
    mint(c, 'attempt-1', 'attempt-1b');
    const second = fireEvaluation(c, 'attempt-1b', ['q:1|stage.x']);

    const { attributed, violations } = attribute(sealed(c), [v1]);
    expect(violations).toEqual([]);
    expect(attributed[second].lineage).toBe('ok');
  });

  test('a recursive mint chain roots at the rendered attempt', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    mint(c, 'attempt-1', 'attempt-1b');
    mint(c, 'attempt-1b', 'attempt-1c');
    const third = fireEvaluation(c, 'attempt-1c', ['q:1|stage.x']);

    const { violations, attributed } = attribute(sealed(c), [v1]);
    expect(violations).toEqual([]);
    expect(attributed[third].lineage).toBe('ok');
  });

  test('rooting is causal: a mint issued before its parent existed is never retroactively rooted', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    // B -> C completes first; A -> B completes after; both before the
    // evaluation. Graph closure would accept C — causal rooting must not:
    // the B -> C request started when B was not yet in the lineage.
    mint(c, 'attempt-1b', 'attempt-1c');
    mint(c, 'attempt-1', 'attempt-1b');
    const evaluation = fireEvaluation(c, 'attempt-1c', ['q:1|stage.x']);

    const { attributed, violations } = attribute(sealed(c), [v1]);
    expect(attributed[evaluation].lineage).toBe('violation');
    expect(violations[0].attemptGuid).toBe('attempt-1c');
  });

  test('overlapping mint requests still root when each target predates the request', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const first = mint(c, 'attempt-1', 'attempt-1b', { respond: false });
    completeMint(c, first, 'attempt-1b');
    const second = mint(c, 'attempt-1b', 'attempt-1c', { respond: false });
    completeMint(c, second, 'attempt-1c');
    const evaluation = fireEvaluation(c, 'attempt-1c', ['q:1|stage.x']);

    const { attributed, violations } = attribute(sealed(c), [v1]);
    expect(violations).toEqual([]);
    expect(attributed[evaluation].lineage).toBe('ok');
  });

  test('a mint that responds AFTER the evaluation confers nothing', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const pending = mint(c, 'attempt-1', 'attempt-1b', { respond: false });
    const evaluation = fireEvaluation(c, 'attempt-1b', ['q:1|stage.x']);
    completeMint(c, pending, 'attempt-1b');

    const { attributed, violations } = attribute(sealed(c), [v1]);
    expect(attributed[evaluation].lineage).toBe('violation');
    expect(violations).toEqual([
      {
        kind: 'lineage',
        screenId: 'q:1',
        attemptGuid: 'attempt-1b',
        requestSeq: expect.any(Number),
      },
    ]);
  });

  test('failed and unparsed mints confer nothing', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    mint(c, 'attempt-1', 'attempt-1b', { status: 500 });
    const underFailed = fireEvaluation(c, 'attempt-1b', ['q:1|stage.x']);
    mint(c, 'attempt-1', 'attempt-1c', { parsed: false });
    const underUnparsed = fireEvaluation(c, 'attempt-1c', ['q:1|stage.x']);

    const { attributed } = attribute(sealed(c), [v1]);
    expect(attributed[underFailed].lineage).toBe('violation');
    expect(attributed[underUnparsed].lineage).toBe('violation');
  });

  test('an owned evaluation under a foreign attempt is a violation, not silently owned', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const foreign = fireEvaluation(c, 'attempt-from-elsewhere', ['q:1|stage.x']);

    const { attributed, violations } = attribute(sealed(c), [v1]);
    expect(attributed[foreign].lineage).toBe('violation');
    expect(violations[0].attemptGuid).toBe('attempt-from-elsewhere');
  });

  test('a pathless evaluation is owned by its window and lineage-checked the same way', () => {
    const c = journal();
    const v1 = visit(c, 'nav:1', 'attempt-nav');
    const own = firePathlessEvaluation(c, 'attempt-nav');
    const v2 = visit(c, 'nav:2', 'attempt-nav-2');
    const delayedForeign = firePathlessEvaluation(c, 'attempt-nav');

    const { attributed } = attribute(sealed(c), [v1, v2]);
    expect(attributed[own].ownerScreenId).toBe('nav:1');
    expect(attributed[own].lineage).toBe('ok');
    expect(attributed[delayedForeign].ownerScreenId).toBe('nav:2');
    expect(attributed[delayedForeign].lineage).toBe('violation');
  });

  test('saves, creations and activity finalizes are attributed but never lineage-judged', () => {
    const c = journal();
    const v1 = visit(c, 'q:1', 'attempt-1');
    const save = c.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/attempt-1/active`,
      postData: JSON.stringify({ partInputs: [] }),
    }) as number;
    const creation = mint(c, 'attempt-1', 'attempt-1b');
    const finalize = c.ingestRequest({
      method: 'PUT',
      url: `${ORIGIN}/state/course/s1/activity_attempt/foreign-guid`,
      postData: JSON.stringify({ partInputs: [] }),
    }) as number;
    c.ingestResponse(finalize, 200);
    c.ingestResponseBody(finalize, JSON.stringify({ type: 'success' }));

    const { attributed, violations } = attribute(sealed(c), [v1]);
    expect(violations).toEqual([]);
    for (const h of [save, creation, finalize]) {
      expect(attributed[h].ownerScreenId).toBe('q:1');
      expect(attributed[h].lineage).toBeNull();
    }
  });
});

test.describe('payload provenance by precedence', () => {
  const MANIFEST = new Set(['q:1', 'q:2', 'dep:1']);

  test('own prefix, declared dependency and non-manifest ancestor are legal', () => {
    const { classified, violations } = resolveProvenance({
      submittedPrefixes: ['q:1', 'dep:1', 'layer:parent'],
      owningScreenId: 'q:1',
      declaredDependencies: ['dep:1'],
      ancestors: ['layer:parent'],
      manifestScreenIds: MANIFEST,
    });
    expect(violations).toEqual([]);
    expect(classified).toEqual([
      { prefix: 'q:1', class: 'own' },
      { prefix: 'dep:1', class: 'dependency' },
      { prefix: 'layer:parent', class: 'ancestor' },
    ]);
  });

  test('a manifest-screen prefix that is not a declared dependency is contamination — even as an ancestor', () => {
    const { violations } = resolveProvenance({
      submittedPrefixes: ['q:2'],
      owningScreenId: 'q:1',
      declaredDependencies: [],
      ancestors: ['q:2'],
      manifestScreenIds: MANIFEST,
    });
    expect(violations).toEqual(['q:2']);
  });

  test('an unknown prefix is a violation — no blanket tolerance of non-manifest prefixes', () => {
    const { violations } = resolveProvenance({
      submittedPrefixes: ['stranger:1'],
      owningScreenId: 'q:1',
      declaredDependencies: [],
      ancestors: [],
      manifestScreenIds: MANIFEST,
    });
    expect(violations).toEqual(['stranger:1']);
  });
});

test.describe('submitted prefix extraction', () => {
  test('reads both wire shapes and never invents prefixes for pathless payloads', () => {
    const nested = [
      { response: { input: { k: { path: 'q:1|stage.x', value: 1 } } } },
      { response: { input: { k: { path: 'q:2|stage.y', value: 2 } } } },
    ];
    const inline = [{ response: { k: { path: 'q:3|stage.z', value: 3 } } }];
    expect(extractSubmittedPrefixes(nested)).toEqual(['q:1', 'q:2']);
    expect(extractSubmittedPrefixes(inline)).toEqual(['q:3']);
    expect(extractSubmittedPrefixes([])).toEqual([]);
    expect(extractSubmittedPrefixes(null)).toEqual([]);
    expect(extractSubmittedPrefixes([{ response: { k: { path: 'no-separator' } } }])).toEqual([]);
  });
});
