import { Page, expect, test } from '@playwright/test';
import {
  AdaptiveJournalCore,
  AdaptiveJournalRecorder,
  FinalizationFailureReason,
  RunCorrelation,
} from '@tasks/AdaptiveJournal';

/**
 * MER-5865 step 1: deterministic contract matrix for the journal core —
 * request-time classification precedence (positive AND mismatched rows),
 * finalization acceptance crossed with every rejection shape, the combined
 * freeze state machine (both flavors × ordering violations × persistent-mode
 * arrivals), two-phase response stamping, audited-state immutability,
 * seal-boundary membership, and entry-stamp fencing in both orderings
 * (spec §3.2, §8). The core is pure; only the adapter tests at the bottom
 * touch a page.
 */

const ORIGIN = 'https://adaptive-stub.local';
const CORR: RunCorrelation = {
  sectionSlug: 'section-1',
  revisionSlug: 'revision-1',
  resourceAttemptGuid: 'resource-attempt-1',
};

const PART = {
  attemptGuid: 'part-guid-1',
  response: { input: { item: { path: 'q:1|stage.dropdown.selectedItem', value: 'Basalt' } } },
};

function core(): AdaptiveJournalCore {
  const c = new AdaptiveJournalCore(() => 1_000);
  c.setRunCorrelation(CORR);
  return c;
}

function request(
  c: AdaptiveJournalCore,
  method: string,
  path: string,
  body: unknown = { partInputs: [PART] },
): number {
  const handle = c.ingestRequest({
    method,
    url: `${ORIGIN}${path}`,
    postData: body === null ? null : JSON.stringify(body),
  });
  if (handle === null) throw new Error(`journal ignored ${method} ${path}`);
  return handle;
}

const putEval = (c: AdaptiveJournalCore, guid = 'attempt-1') =>
  request(c, 'PUT', `/state/course/s1/activity_attempt/${guid}`);
const patchSave = (c: AdaptiveJournalCore, guid = 'attempt-1') =>
  request(c, 'PATCH', `/state/course/s1/activity_attempt/${guid}/active`);
const postCreation = (c: AdaptiveJournalCore, guid = 'attempt-1') =>
  request(c, 'POST', `/state/course/s1/activity_attempt/${guid}`, {});

function respond(c: AdaptiveJournalCore, handle: number, body: unknown, status = 200) {
  c.ingestResponse(handle, status);
  c.ingestResponseBody(handle, body === null ? null : JSON.stringify(body));
}

const respondCorrect = (c: AdaptiveJournalCore, handle: number, correct = true) =>
  respond(c, handle, { actions: { correct } });

function postFinalization(c: AdaptiveJournalCore, bodyOver: Record<string, unknown> = {}): number {
  return request(c, 'POST', '/page_lifecycle', {
    action: 'finalize',
    section_slug: CORR.sectionSlug,
    revision_slug: CORR.revisionSlug,
    attempt_guid: CORR.resourceAttemptGuid,
    ...bodyOver,
  });
}

const respondFinalization = (
  c: AdaptiveJournalCore,
  handle: number,
  over: Record<string, unknown> = {},
  status = 200,
) => respond(c, handle, { result: 'success', commandResult: 'success', ...over }, status);

function acceptedLessonEnd(c: AdaptiveJournalCore) {
  c.noteLessonEnd();
  respondFinalization(c, postFinalization(c));
}

test.describe('journal request-time classification', () => {
  test('fixes the wire class from URL + method alone', () => {
    const c = core();
    const save = patchSave(c);
    const creation = postCreation(c);
    const evaluation = putEval(c);
    const finalization = postFinalization(c);

    expect(c.records()[save].wireClass).toBe('save');
    expect(c.records()[creation].wireClass).toBe('creation');
    expect(c.records()[evaluation].wireClass).toBe('eval-candidate');
    expect(c.records()[evaluation].resolution).toBe('unresolved');
    expect(c.records()[finalization].wireClass).toBe('page-finalization');
    expect(c.records()[evaluation].attemptGuid).toBe('attempt-1');
  });

  test('rejects every mismatched method × URL row, not just non-journal URLs', () => {
    const c = core();
    const rows: Array<[string, string]> = [
      ['GET', '/state/course/s1/activity_attempt/attempt-1'],
      ['DELETE', '/state/course/s1/activity_attempt/attempt-1'],
      ['PATCH', '/state/course/s1/activity_attempt/attempt-1'],
      ['POST', '/state/course/s1/activity_attempt/attempt-1/active'],
      ['PUT', '/state/course/s1/activity_attempt/attempt-1/active'],
      ['PUT', '/page_lifecycle'],
      ['GET', '/page_lifecycle'],
      ['PUT', '/other/endpoint'],
      ['GET', '/course'],
    ];
    for (const [method, path] of rows) {
      expect(
        c.ingestRequest({ method, url: `${ORIGIN}${path}`, postData: '{}' }),
        `${method} ${path} must not classify`,
      ).toBeNull();
    }
    expect(
      c.ingestRequest({
        method: 'POST',
        url: `${ORIGIN}/page_lifecycle`,
        postData: JSON.stringify({ action: 'mark_completed' }),
      }),
    ).toBeNull();
    expect(c.records()).toHaveLength(0);
  });

  test('a PUT resolves to evaluation only on a boolean actions.correct', () => {
    const c = core();
    const h = putEval(c);
    respondCorrect(c, h, false);
    expect(c.records()[h].resolution).toBe('evaluation');
    expect(c.records()[h].correct).toBe(false);
  });

  test('a bare-success PUT resolves to an activity finalize, never an evaluation', () => {
    const c = core();
    const h = putEval(c);
    respond(c, h, { type: 'success' });
    expect(c.records()[h].resolution).toBe('activity-finalize');
    expect(c.records()[h].correct).toBeNull();
  });

  test('a PUT with an unusable response stays an unresolved candidate — fail-closed', () => {
    const c = core();
    const garbage = putEval(c);
    respond(c, garbage, {});
    const errored = putEval(c);
    respond(c, errored, { actions: { correct: true } }, 500);
    const failed = putEval(c);
    c.ingestRequestFailed(failed);
    const silent = putEval(c);

    for (const h of [garbage, errored, failed, silent]) {
      expect(c.records()[h].resolution).toBe('unresolved');
    }
    expect(c.records()[garbage].parseError).toMatch(/no boolean actions.correct/);
    expect(c.records()[errored].parseError).toMatch(/status 500/);
    expect(c.records()[failed].terminal).toBe('failed');
    expect(c.records()[silent].terminal).toBeNull();
  });

  test('a pathless request body is recorded with a parse error, not dropped', () => {
    const c = core();
    const h = request(c, 'PUT', '/state/course/s1/activity_attempt/attempt-1', {});
    expect(c.records()[h].partInputs).toBeNull();
    expect(c.records()[h].parseError).toMatch(/no partInputs array/);
  });

  test('creation responses record the minted guid', () => {
    const c = core();
    const h = postCreation(c, 'target-guid');
    respond(c, h, { attemptState: { attemptGuid: 'minted-guid' } });
    expect(c.records()[h].attemptGuid).toBe('target-guid');
    expect(c.records()[h].mintedGuid).toBe('minted-guid');
  });
});

test.describe('two-phase response stamping', () => {
  test('the response seq is the observed event; a late body fill never moves it', () => {
    const c = core();
    const mint = postCreation(c, 'attempt-1');
    c.ingestResponse(mint, 200);
    const fence = c.issueFence('q:2');
    const evaluation = putEval(c, 'attempt-1b');
    c.ingestResponseBody(mint, JSON.stringify({ attemptState: { attemptGuid: 'attempt-1b' } }));

    const mintRecord = c.records()[mint];
    expect(mintRecord.responseSeq).toBeLessThan(fence.seq);
    expect(mintRecord.responseSeq).toBeLessThan(c.records()[evaluation].requestSeq);
    expect(mintRecord.mintedGuid).toBe('attempt-1b');
    expect(mintRecord.terminal).toBe('completed');
  });

  test('a record with a stamped response but unparsed body is still outstanding', () => {
    const c = core();
    const h = putEval(c);
    c.ingestResponse(h, 200);
    expect(c.outstanding()).toBe(1);
    c.ingestResponseBody(h, JSON.stringify({ actions: { correct: true } }));
    expect(c.outstanding()).toBe(0);
    expect(c.records()[h].resolution).toBe('evaluation');
  });

  test('a body without a stamped response event is ignored', () => {
    const c = core();
    const h = putEval(c);
    c.ingestResponseBody(h, JSON.stringify({ actions: { correct: true } }));
    expect(c.records()[h].resolution).toBe('unresolved');
    expect(c.records()[h].terminal).toBeNull();
  });

  test('a failure after response headers keeps the stamp and ends failed, never completed', () => {
    const c = core();
    const h = putEval(c);
    c.ingestResponse(h, 200);
    const stampedSeq = c.records()[h].responseSeq;

    c.ingestRequestFailed(h);
    const record = c.records()[h];
    expect(record.responseSeq).toBe(stampedSeq);
    expect(record.status).toBe(200);
    expect(record.terminal).toBe('failed');
    expect(record.resolution).toBe('unresolved');

    // a body that straggles in after the failure changes nothing
    c.ingestResponseBody(h, JSON.stringify({ actions: { correct: true } }));
    expect(c.records()[h].resolution).toBe('unresolved');
    expect(c.records()[h].terminal).toBe('failed');
  });
});

test.describe('finalization acceptance contract', () => {
  test('accepted only when correlated, parsed, 2xx, success/success', () => {
    const c = core();
    respondFinalization(c, postFinalization(c));
    expect(c.finalizationStatus()).toEqual({ kind: 'accepted' });
  });

  test('each wrong correlation field × each response shape rejects as uncorrelated', () => {
    const shapes: Array<Record<string, unknown>> = [
      {},
      { result: 'error' },
      { commandResult: 'failure', reason: 'deadline' },
      { commandResult: 'failure', reason: 'already_submitted' },
    ];
    for (const field of ['section_slug', 'revision_slug', 'attempt_guid']) {
      for (const shape of shapes) {
        const c = core();
        respondFinalization(c, postFinalization(c, { [field]: 'someone-elses' }), shape);
        expect(
          c.finalizationStatus(),
          `${field} wrong with shape ${JSON.stringify(shape)}`,
        ).toEqual({ kind: 'rejected', reason: 'uncorrelated' });
      }
    }
  });

  test('a correlated finalization rejects by its own defect', () => {
    const already = core();
    respondFinalization(already, postFinalization(already), {
      commandResult: 'failure',
      reason: 'already_submitted',
    });
    expect(already.finalizationStatus()).toEqual({
      kind: 'rejected',
      reason: 'already_submitted',
    });

    const commandFailure = core();
    respondFinalization(commandFailure, postFinalization(commandFailure), {
      commandResult: 'failure',
      reason: 'deadline',
    });
    expect(commandFailure.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'failed' });

    const non2xx = core();
    respondFinalization(non2xx, postFinalization(non2xx), {}, 500);
    expect(non2xx.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'failed' });

    const wrongResult = core();
    respondFinalization(wrongResult, postFinalization(wrongResult), { result: 'error' });
    expect(wrongResult.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'failed' });
  });

  test('an unparseable response rejects as malformed', () => {
    const c = core();
    respond(c, postFinalization(c), null);
    expect(c.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'malformed' });
  });

  test('already_submitted outranks even an accepting success/success shape', () => {
    // the real server always pairs already_submitted with commandResult
    // "failure" (page_lifecycle_controller.ex:127-134); this pins the
    // contract for synthetic journals and any future server shape
    const c = core();
    respondFinalization(c, postFinalization(c), { reason: 'already_submitted' });
    expect(c.finalizationStatus()).toEqual({
      kind: 'rejected',
      reason: 'already_submitted',
    });
  });

  test('crossed duplicate rejections resolve by rank, not by response order', () => {
    const build = (first: Record<string, unknown>, second: Record<string, unknown>) => {
      const c = core();
      respondFinalization(c, postFinalization(c), first);
      respondFinalization(c, postFinalization(c), second);
      return c.finalizationStatus();
    };
    const alreadyThenFailed = build(
      { commandResult: 'failure', reason: 'already_submitted' },
      { commandResult: 'failure', reason: 'deadline' },
    );
    const failedThenAlready = build(
      { commandResult: 'failure', reason: 'deadline' },
      { commandResult: 'failure', reason: 'already_submitted' },
    );
    expect(alreadyThenFailed).toEqual({ kind: 'rejected', reason: 'already_submitted' });
    expect(failedThenAlready).toEqual(alreadyThenFailed);
  });

  test('a failed request rejects as failed; none observed is pending', () => {
    const c = core();
    expect(c.finalizationStatus()).toEqual({ kind: 'pending' });
    c.ingestRequestFailed(postFinalization(c));
    expect(c.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'failed' });
  });

  test('an accepted finalization wins outright — even over a response-less duplicate in flight', () => {
    const c = core();
    postFinalization(c);
    respondFinalization(c, postFinalization(c));
    expect(c.finalizationStatus()).toEqual({ kind: 'accepted' });
  });

  test('without an accepted record an in-flight candidate keeps the status pending', () => {
    const c = core();
    respondFinalization(c, postFinalization(c, { section_slug: 'foreign' }));
    postFinalization(c);
    expect(c.finalizationStatus()).toEqual({ kind: 'pending' });
  });

  test('a wrong correlation field with a non-2xx response still classifies as uncorrelated', () => {
    const c = core();
    respondFinalization(c, postFinalization(c, { section_slug: 'someone-elses' }), {}, 500);
    expect(c.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'uncorrelated' });
  });

  test('an unreadable response outranks correlation — the record cannot be judged at all', () => {
    const c = core();
    respond(c, postFinalization(c, { section_slug: 'someone-elses' }), null);
    expect(c.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'malformed' });
  });

  test('a settled rejection survives an in-flight duplicate at the acceptance-wait expiry', () => {
    // the CATEGORICAL reason short-circuits even the acceptance wait —
    // waiting longer can never cure already_submitted (§3.2)
    const c = core();
    respondFinalization(c, postFinalization(c), {
      commandResult: 'failure',
      reason: 'already_submitted',
    });
    postFinalization(c);
    expect(c.finalizationStatus()).toEqual({ kind: 'rejected', reason: 'already_submitted' });
    expect(c.settledRejectionReason()).toBe('already_submitted');

    // a non-categorical settled rejection still waits on the duplicate
    const waiting = core();
    respondFinalization(waiting, postFinalization(waiting), {
      commandResult: 'failure',
      reason: 'deadline',
    });
    postFinalization(waiting);
    expect(waiting.finalizationStatus()).toEqual({ kind: 'pending' });
    expect(waiting.settledRejectionReason()).toBe('failed');

    const uncorrelated = core();
    respondFinalization(uncorrelated, postFinalization(uncorrelated, { section_slug: 'x' }));
    postFinalization(uncorrelated);
    expect(uncorrelated.settledRejectionReason()).toBe('uncorrelated');

    const nothingSettled = core();
    postFinalization(nothingSettled);
    expect(nothingSettled.settledRejectionReason()).toBeNull();
  });
});

test.describe('freeze state machine', () => {
  test('accepted-freeze requires lesson end, acceptance and zero outstanding — in order', () => {
    const c = core();
    expect(() => c.markFrozenAccepted()).toThrow(/lesson-end signal/);

    c.noteLessonEnd();
    expect(() => c.markFrozenAccepted()).toThrow(/accepted finalization, saw pending/);

    respondFinalization(c, postFinalization(c));
    const outstanding = putEval(c);
    expect(() => c.markFrozenAccepted()).toThrow(/1 outstanding/);

    respondCorrect(c, outstanding);
    c.markFrozenAccepted();
    expect(c.state()).toBe('frozen');
    expect(c.snapshot().freezeFlavor).toBe('accepted');
    expect(c.snapshot().finalizationFailure).toBeNull();
  });

  test('terminalization requires the lesson-end signal and is one-way', () => {
    const c = core();
    expect(() => c.enterTerminalization('missing')).toThrow(/lesson-end signal/);
    c.noteLessonEnd();
    c.enterTerminalization('missing');
    expect(() => c.markFrozenAccepted()).toThrow(/completed-failure/);
  });

  test('completed-failure freeze terminalizes outstanding requests', () => {
    const c = core();
    const hanging = putEval(c);
    c.noteLessonEnd();
    expect(() => c.markFrozenCompletedFailure()).toThrow(/terminalization first/);

    c.enterTerminalization('missing');
    expect(c.records()[hanging].terminal).toBe('unterminated');
    c.markFrozenCompletedFailure();
    const snapshot = c.snapshot();
    expect(snapshot.freezeFlavor).toBe('completed-failure');
    expect(snapshot.finalizationFailure).toEqual({ reason: 'missing' });
  });

  test('every reason × response-less finalization terminalization × post-freeze arrival (§8)', () => {
    const reasons: FinalizationFailureReason[] = [
      'missing',
      'uncorrelated',
      'malformed',
      'failed',
      'already_submitted',
    ];
    for (const reason of reasons) {
      const c = core();
      const responseLess = postFinalization(c); // the finalization itself never answers
      c.noteLessonEnd();
      c.enterTerminalization(reason);
      // the response-less finalization POST is itself terminalized
      expect(c.records()[responseLess].terminal, reason).toBe('unterminated');
      // persistent mode: an arrival BEFORE the freeze is terminal on observation
      const late = putEval(c);
      expect(c.records()[late].terminal, reason).toBe('unterminated');
      c.markFrozenCompletedFailure();
      const frozen = c.snapshot();
      expect(frozen.finalizationFailure, reason).toEqual({ reason });
      // post-freeze: the recorder is detached — new traffic is REFUSED, so
      // the frozen audited object can never mutate
      const postFreeze = c.ingestRequest({
        method: 'PUT',
        url: 'https://stub.local/state/course/s1/activity_attempt/late-1',
        postData: '{}',
      });
      expect(postFreeze, reason).toBeNull();
      expect(c.records().length, reason).toBe(frozen.records.length);
    }
  });

  test('an accepted duplicate crossed with a categorical rejection — both response orders (§8)', () => {
    const acceptedFirst = core();
    respondFinalization(acceptedFirst, postFinalization(acceptedFirst));
    respondFinalization(acceptedFirst, postFinalization(acceptedFirst), {
      commandResult: 'failure',
      reason: 'already_submitted',
    });
    expect(acceptedFirst.finalizationStatus()).toEqual({
      kind: 'rejected',
      reason: 'already_submitted',
    });

    const categoricalFirst = core();
    respondFinalization(categoricalFirst, postFinalization(categoricalFirst), {
      commandResult: 'failure',
      reason: 'already_submitted',
    });
    respondFinalization(categoricalFirst, postFinalization(categoricalFirst));
    expect(categoricalFirst.finalizationStatus()).toEqual(acceptedFirst.finalizationStatus());
  });

  test('terminalization is a persistent mode: new arrivals are terminal on observation', () => {
    const c = core();
    c.noteLessonEnd();
    c.enterTerminalization('failed');

    const late = putEval(c);
    expect(c.records()[late].terminal).toBe('unterminated');
    expect(c.outstanding()).toBe(0);

    respond(c, late, { actions: { correct: true } });
    expect(c.records()[late].status).toBeNull();
    expect(c.records()[late].resolution).toBe('unresolved');
  });

  test('events for terminalized records still count as observed traffic for quiescence', () => {
    const c = core();
    c.noteLessonEnd();
    c.enterTerminalization('failed');
    const late = putEval(c);

    const seen = c.wireEventCount();
    c.ingestResponse(late, 200);
    expect(c.wireEventCount()).toBe(seen + 1);
    c.ingestRequestFailed(late);
    expect(c.wireEventCount()).toBe(seen + 2);
    // body-parse completion is NOT a wire event
    c.ingestResponseBody(late, '{}');
    expect(c.wireEventCount()).toBe(seen + 2);
    expect(c.records()[late].status).toBeNull();
  });

  test('frozen is terminal: no new traffic, fences, freezes or seals — both flavors', () => {
    const accepted = core();
    acceptedLessonEnd(accepted);
    accepted.markFrozenAccepted();

    const completedFailure = core();
    completedFailure.noteLessonEnd();
    completedFailure.enterTerminalization('missing');
    completedFailure.markFrozenCompletedFailure();

    for (const c of [accepted, completedFailure]) {
      expect(
        c.ingestRequest({ method: 'PUT', url: `${ORIGIN}/x/activity_attempt/g`, postData: '{}' }),
      ).toBeNull();
      expect(() => c.issueFence('q:1')).toThrow(/while frozen/);
      expect(() => c.markFrozenAccepted()).toThrow(/while frozen/);
      expect(() => c.beginSeal()).toThrow(/while frozen/);
      expect(() => c.noteLessonEnd()).toThrow(/while frozen/);
    }
  });

  test('no snapshot of an armed journal', () => {
    expect(() => core().snapshot()).toThrow(/journal that is armed/);
  });

  test('a freeze timeout is typed positive evidence that survives into the sealed snapshot', () => {
    const c = core();
    expect(() => c.markFreezeTimeout()).toThrow(/lesson-end signal/);

    acceptedLessonEnd(c);
    c.markFreezeTimeout();
    c.beginSeal();
    c.finishSeal();

    const snapshot = c.snapshot();
    expect(snapshot.state).toBe('sealed');
    // the seal is COMPLETE — without this record the bail would audit clean
    expect(snapshot.sealIncomplete).toBe(false);
    expect(snapshot.freezeTimeout).toEqual({ outstanding: 0 });
    expect(snapshot.freezeFlavor).toBeNull();
  });
});

test.describe('audited-state immutability', () => {
  test('records() and fences() hand out clones — retained references cannot poison a snapshot', () => {
    const c = core();
    const h = putEval(c);
    respondCorrect(c, h);
    const fence = c.issueFence('q:1');
    c.beginSeal();
    c.finishSeal();

    const grabbedRecord = c.records()[h];
    grabbedRecord.correct = false;
    grabbedRecord.terminal = 'failed';
    const grabbedFence = c.fences()[0];
    grabbedFence.screenId = 'imposter';

    const snapshot = c.snapshot();
    expect(snapshot.records[h].correct).toBe(true);
    expect(snapshot.records[h].terminal).toBe('completed');
    expect(snapshot.fences[0].screenId).toBe('q:1');
    expect(fence.screenId).toBe('q:1');
  });

  test('sealed is terminal for every mutator', () => {
    const c = core();
    const h = putEval(c);
    respondCorrect(c, h);
    c.beginSeal();
    c.finishSeal();

    expect(() => c.noteLessonEnd()).toThrow(/while sealed/);
    expect(() => c.issueFence('q:1')).toThrow(/while sealed/);
    expect(() => c.markFreezeTimeout()).toThrow(/while sealed/);
    c.ingestResponse(h, 500);
    c.ingestResponseBody(h, JSON.stringify({ actions: { correct: false } }));
    c.ingestRequestFailed(h);
    const snapshot = c.snapshot();
    expect(snapshot.records[h].status).toBe(200);
    expect(snapshot.records[h].correct).toBe(true);
    expect(snapshot.records[h].terminal).toBe('completed');
  });

  test('the stamp issueFence returns is a copy — mutating it cannot rewrite the journal', () => {
    const c = core();
    const stamp = c.issueFence('q:1');
    stamp.screenId = 'imposter';
    stamp.seq = 999;
    c.beginSeal();
    c.finishSeal();

    const snapshot = c.snapshot();
    expect(snapshot.fences[0].screenId).toBe('q:1');
    expect(snapshot.fences[0].seq).toBe(1);
  });

  test('correlation is one-time, armed-only, and stored by copy', () => {
    const sealedCore = core();
    sealedCore.beginSeal();
    sealedCore.finishSeal();
    expect(() => sealedCore.setRunCorrelation(CORR)).toThrow(/while sealed/);

    const c = new AdaptiveJournalCore(() => 1_000);
    const mutable = { ...CORR };
    c.setRunCorrelation(mutable);
    expect(() => c.setRunCorrelation(CORR)).toThrow(/already set/);

    mutable.sectionSlug = 'someone-elses';
    respondFinalization(c, postFinalization(c));
    expect(c.finalizationStatus()).toEqual({ kind: 'accepted' });
  });
});

test.describe('seal-boundary membership', () => {
  test('membership is requestSeq <= cutoff alone; members complete during sealing', () => {
    const c = core();
    const member = putEval(c);
    c.beginSeal();

    respondCorrect(c, member);
    expect(c.records()[member].terminal).toBe('completed');

    const marker = putEval(c);
    expect(c.records()[marker].postSeal).toBe(true);

    c.finishSeal();
    const snapshot = c.snapshot();
    expect(snapshot.state).toBe('sealed');
    expect(snapshot.sealIncomplete).toBe(false);
    expect(snapshot.records).toHaveLength(1);
    expect(snapshot.records[0].resolution).toBe('evaluation');
    expect(snapshot.postSealMarkers).toBe(1);
  });

  test('seal_incomplete is derived: an outstanding member forces it, a settled set forbids it', () => {
    const c = core();
    const hanging = putEval(c);
    c.beginSeal();
    c.finishSeal();

    const snapshot = c.snapshot();
    expect(snapshot.sealIncomplete).toBe(true);
    expect(snapshot.records[hanging].terminal).toBe('unterminated');
  });

  test('an outstanding post-seal marker never makes the snapshot incomplete', () => {
    const c = core();
    const member = putEval(c);
    respondCorrect(c, member);
    c.beginSeal();
    putEval(c);
    c.finishSeal();

    const snapshot = c.snapshot();
    expect(snapshot.sealIncomplete).toBe(false);
    expect(snapshot.records).toHaveLength(1);
    expect(snapshot.postSealMarkers).toBe(1);
  });

  test('seal transitions are guarded', () => {
    const c = core();
    expect(() => c.finishSeal()).toThrow(/while armed/);
    c.beginSeal();
    expect(() => c.beginSeal()).toThrow(/while sealing/);
    c.finishSeal();
    expect(() => c.beginSeal()).toThrow(/while sealed/);
  });
});

test.describe('entry-stamp fencing', () => {
  test('a fence and a request racing it have one strict order — both orderings', () => {
    const before = core();
    const req = putEval(before);
    const fence = before.issueFence('q:1');
    expect(before.records()[req].requestSeq).toBeLessThan(fence.seq);

    const after = core();
    const fence2 = after.issueFence('q:1');
    const req2 = putEval(after);
    expect(after.records()[req2].requestSeq).toBeGreaterThan(fence2.seq);
  });

  test('responses, fences and the lesson-end signal share the seq domain', () => {
    const c = core();
    const fence = c.issueFence('q:1');
    const h = putEval(c);
    respondCorrect(c, h);
    c.noteLessonEnd();

    const record = c.records()[h];
    expect(fence.seq).toBeLessThan(record.requestSeq);
    expect(record.requestSeq).toBeLessThan(record.responseSeq as number);
  });
});

test.describe('journal recorder on a live page', () => {
  async function boot(page: Page, opts: { evalDelayMs?: number } = {}) {
    await page.route(`${ORIGIN}/**`, async (route) => {
      const req = route.request();
      if (req.method() === 'GET') {
        return route.fulfill({ status: 200, contentType: 'text/html', body: '<html></html>' });
      }
      if (req.url().includes('/page_lifecycle')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ result: 'success', commandResult: 'success' }),
        });
      }
      if (req.url().includes('/abort')) return route.abort();
      if (opts.evalDelayMs) await new Promise((r) => setTimeout(r, opts.evalDelayMs));
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ actions: { correct: true } }),
      });
    });
    const recorder = new AdaptiveJournalRecorder(page);
    recorder.core.setRunCorrelation(CORR);
    recorder.attach();
    await page.goto(`${ORIGIN}/`);
    return recorder;
  }

  const fire = (page: Page, method: string, path: string, body: unknown) =>
    page.evaluate(
      async (args) => {
        await fetch(args.path, {
          method: args.method,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify(args.body),
        }).catch(() => undefined);
      },
      { method, path, body },
    );

  // fire-and-forget: resolves at REQUEST time so the response lands later,
  // while the freeze orchestration is already running (§8: genuinely late
  // traffic, not awaited fetches)
  const fireLate = (page: Page, method: string, path: string, body: unknown) =>
    page.evaluate(
      (args) => {
        void fetch(args.path, {
          method: args.method,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify(args.body),
        }).catch(() => undefined);
      },
      { method, path, body },
    );

  const finalizeBody = {
    action: 'finalize',
    section_slug: CORR.sectionSlug,
    revision_slug: CORR.revisionSlug,
    attempt_guid: CORR.resourceAttemptGuid,
  };

  test('records live traffic and takes the accepted freeze', async ({ page }) => {
    const recorder = await boot(page);
    try {
      await fire(page, 'PUT', '/state/course/s1/activity_attempt/attempt-1', {
        partInputs: [PART],
      });
      await fire(page, 'POST', '/page_lifecycle', finalizeBody);
      recorder.core.noteLessonEnd();
      const flavor = await recorder.awaitFreeze({ quiescenceMs: 100 });
      expect(flavor).toBe('accepted');

      const snapshot = recorder.core.snapshot();
      const evaluation = snapshot.records.find((r) => r.resolution === 'evaluation');
      expect(evaluation?.attemptGuid).toBe('attempt-1');
      expect(evaluation?.partInputs).toHaveLength(1);
    } finally {
      recorder.detach();
    }
  });

  test('a post-zero arrival restarts the accepted path instead of throwing', async ({ page }) => {
    const recorder = await boot(page, { evalDelayMs: 400 });
    try {
      await fire(page, 'POST', '/page_lifecycle', finalizeBody);
      recorder.core.noteLessonEnd();
      // outstanding is 0 and finalization accepted; start the freeze FIRST,
      // then land a request mid-quiescence that stays open for 400 ms — the
      // loop must drain and re-quiesce, not throw
      const freezing = recorder.awaitFreeze({ quiescenceMs: 300 });
      await page.waitForTimeout(100);
      await fireLate(page, 'PUT', '/state/course/s1/activity_attempt/late-1', {
        partInputs: [PART],
      });
      expect(await freezing).toBe('accepted');

      const late = recorder.core.snapshot().records.find((r) => r.attemptGuid === 'late-1');
      expect(late?.terminal).toBe('completed');
      expect(late?.resolution).toBe('evaluation');
    } finally {
      recorder.detach();
    }
  });

  test('a categorical duplicate settling DURING the accepted drain flips the run to completed-failure (§8)', async ({
    page,
  }) => {
    const recorder = await boot(page);
    try {
      // the duplicate endpoint answers success + already_submitted — the
      // categorical shape; registered after boot so it wins route precedence
      await page.route(`${ORIGIN}/page_lifecycle?dup=1`, (route) =>
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            result: 'success',
            commandResult: 'failure',
            reason: 'already_submitted',
          }),
        }),
      );
      await fire(page, 'POST', '/page_lifecycle', finalizeBody);
      recorder.core.noteLessonEnd();
      // acceptance is observed FIRST; the categorical duplicate lands while
      // the accepted branch is draining — the freeze must flip, not throw
      const freezing = recorder.awaitFreeze({ quiescenceMs: 300 });
      await page.waitForTimeout(100);
      await fire(page, 'POST', '/page_lifecycle?dup=1', finalizeBody);
      expect(await freezing).toBe('completed-failure');

      const snapshot = recorder.core.snapshot();
      expect(snapshot.freezeFlavor).toBe('completed-failure');
      expect(snapshot.finalizationFailure).toEqual({ reason: 'already_submitted' });
    } finally {
      recorder.detach();
    }
  });

  test('a missing finalization takes the completed-failure freeze', async ({ page }) => {
    const recorder = await boot(page);
    try {
      await fire(page, 'PUT', '/state/course/s1/activity_attempt/attempt-1', {
        partInputs: [PART],
      });
      recorder.core.noteLessonEnd();
      const flavor = await recorder.awaitFreeze({ finalizationTimeoutMs: 300, quiescenceMs: 100 });
      expect(flavor).toBe('completed-failure');
      expect(recorder.core.snapshot().finalizationFailure).toEqual({ reason: 'missing' });
    } finally {
      recorder.detach();
    }
  });

  test('an expired acceptance wait preserves a settled rejection over missing', async ({
    page,
  }) => {
    const recorder = await boot(page);
    // the first finalization settles as already_submitted; the duplicate
    // never responds — the deadline must keep the SETTLED reason
    let calls = 0;
    await page.route(`${ORIGIN}/page_lifecycle`, async (route) => {
      calls += 1;
      if (calls === 1) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            result: 'success',
            commandResult: 'failure',
            reason: 'already_submitted',
          }),
        });
      }
      await new Promise((r) => setTimeout(r, 10_000));
    });
    try {
      await fire(page, 'POST', '/page_lifecycle', finalizeBody);
      await fireLate(page, 'POST', '/page_lifecycle', finalizeBody);
      recorder.core.noteLessonEnd();
      const flavor = await recorder.awaitFreeze({
        finalizationTimeoutMs: 400,
        quiescenceMs: 100,
        freezeTimeoutMs: 3_000,
      });
      expect(flavor).toBe('completed-failure');
      expect(recorder.core.snapshot().finalizationFailure).toEqual({
        reason: 'already_submitted',
      });
    } finally {
      recorder.detach();
    }
  });

  test('freezeTimeoutMs bounds the whole call even when the finalization wait is longer', async ({
    page,
  }) => {
    const recorder = await boot(page);
    try {
      recorder.core.noteLessonEnd();
      const startedAt = Date.now();
      const flavor = await recorder.awaitFreeze({
        finalizationTimeoutMs: 60_000,
        quiescenceMs: 100,
        freezeTimeoutMs: 600,
      });
      expect(flavor).toBe('completed-failure');
      expect(Date.now() - startedAt).toBeLessThan(5_000);
      expect(recorder.core.snapshot().finalizationFailure).toEqual({ reason: 'missing' });
    } finally {
      recorder.detach();
    }
  });

  test('a quiescence interval that cannot fit the remaining budget throws instead of freezing late', async ({
    page,
  }) => {
    const recorder = await boot(page);
    try {
      await fire(page, 'POST', '/page_lifecycle', finalizeBody);
      recorder.core.noteLessonEnd();
      await expect(
        recorder.awaitFreeze({ quiescenceMs: 10_000, freezeTimeoutMs: 400 }),
      ).rejects.toThrow(/never quiesced.*seal instead/);
      expect(recorder.core.state()).toBe('armed');
    } finally {
      recorder.detach();
    }
  });

  test('settled informational traffic that never quiesces bails with typed evidence, then seals clean', async ({
    page,
  }) => {
    const recorder = await boot(page);
    try {
      await fire(page, 'POST', '/page_lifecycle', finalizeBody);
      recorder.core.noteLessonEnd();
      // PATCH saves complete instantly (zero outstanding at every sample) but
      // keep the wire alive past the deadline — the bail must still leave
      // positive audit evidence in the sealed snapshot
      await page.evaluate(() => {
        const w = window as unknown as { saveSpam?: ReturnType<typeof setInterval> };
        w.saveSpam = setInterval(() => {
          void fetch('/state/course/s1/activity_attempt/save-target/active', {
            method: 'PATCH',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ partInputs: [] }),
          }).catch(() => undefined);
        }, 100);
      });
      await expect(
        recorder.awaitFreeze({ quiescenceMs: 400, freezeTimeoutMs: 1_500 }),
      ).rejects.toThrow(/never quiesced/);

      await page.evaluate(() => {
        const w = window as unknown as { saveSpam?: ReturnType<typeof setInterval> };
        if (w.saveSpam) clearInterval(w.saveSpam);
      });
      await recorder.seal();
      const snapshot = recorder.core.snapshot();
      expect(snapshot.state).toBe('sealed');
      expect(snapshot.freezeTimeout).not.toBeNull();
      expect(snapshot.records.some((r) => r.wireClass === 'save')).toBe(true);
    } finally {
      recorder.detach();
    }
  });

  test('a continuing terminalized stream delays but cannot hang the completed-failure freeze', async ({
    page,
  }) => {
    const recorder = await boot(page);
    try {
      recorder.core.noteLessonEnd();
      await page.evaluate(() => {
        const w = window as unknown as { spam?: ReturnType<typeof setInterval> };
        w.spam = setInterval(() => {
          void fetch('/state/course/s1/activity_attempt/spam-1', {
            method: 'PUT',
            headers: { 'content-type': 'application/json' },
            body: '{}',
          }).catch(() => undefined);
        }, 100);
      });
      const flavor = await recorder.awaitFreeze({
        finalizationTimeoutMs: 100,
        quiescenceMs: 400,
        freezeTimeoutMs: 2_000,
      });
      expect(flavor).toBe('completed-failure');
      expect(recorder.core.state()).toBe('frozen');
    } finally {
      await page
        .evaluate(() => {
          const w = window as unknown as { spam?: ReturnType<typeof setInterval> };
          if (w.spam) clearInterval(w.spam);
        })
        .catch(() => undefined);
      recorder.detach();
    }
  });

  test('an accepted finalization with hanging traffic throws for the seal path', async ({
    page,
  }) => {
    const recorder = await boot(page, { evalDelayMs: 60_000 });
    try {
      await fire(page, 'POST', '/page_lifecycle', finalizeBody);
      recorder.core.noteLessonEnd();
      await fireLate(page, 'PUT', '/state/course/s1/activity_attempt/hang-1', {
        partInputs: [PART],
      });
      await expect.poll(() => recorder.core.outstanding(), { timeout: 5_000 }).toBeGreaterThan(0);

      await expect(
        recorder.awaitFreeze({ quiescenceMs: 100, freezeTimeoutMs: 800 }),
      ).rejects.toThrow(/never quiesced.*seal instead/);

      await recorder.seal(500);
      const snapshot = recorder.core.snapshot();
      expect(snapshot.state).toBe('sealed');
      expect(snapshot.sealIncomplete).toBe(true);
    } finally {
      recorder.detach();
    }
  });

  test('an aborted request is terminal-recorded, and a bail seals with it settled', async ({
    page,
  }) => {
    const recorder = await boot(page);
    try {
      await fire(page, 'PUT', '/state/course/s1/activity_attempt/abort', { partInputs: [PART] });
      await expect.poll(() => recorder.core.outstanding()).toBe(0);
      await recorder.seal();

      const snapshot = recorder.core.snapshot();
      expect(snapshot.state).toBe('sealed');
      expect(snapshot.sealIncomplete).toBe(false);
      expect(snapshot.records[0].terminal).toBe('failed');
      expect(snapshot.records[0].resolution).toBe('unresolved');
    } finally {
      recorder.detach();
    }
  });
});
