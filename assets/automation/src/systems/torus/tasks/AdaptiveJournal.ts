import { Page, Request, Response } from '@playwright/test';
import { CheckActions } from '@tasks/AdaptiveStrictContract';

const EVAL_URL = /\/activity_attempt\/([^/?#]+)(?:[?#]|$)/;
const SAVE_URL = /\/activity_attempt\/([^/?#]+)\/active(?:[?#]|$)/;
const PAGE_LIFECYCLE_URL = /\/page_lifecycle(?:[?#]|$)/;

/**
 * Wire class is fixed at REQUEST time from URL + method alone (spec §3.2,
 * fail-closed): a PUT whose response never arrives or fails to parse stays an
 * `unresolved` evaluation candidate — never silently a finalize.
 */
export type WireClass = 'creation' | 'save' | 'eval-candidate' | 'page-finalization';
export type EvalResolution = 'evaluation' | 'activity-finalize' | 'unresolved';
export type RecordTerminal = 'completed' | 'failed' | 'unterminated';
export type JournalState = 'armed' | 'sealing' | 'sealed' | 'frozen';
export type FreezeFlavor = 'accepted' | 'completed-failure';
export type FinalizationFailureReason =
  | 'missing'
  | 'uncorrelated'
  | 'malformed'
  | 'failed'
  | 'already_submitted';

export type RunCorrelation = {
  sectionSlug: string;
  revisionSlug: string;
  resourceAttemptGuid: string;
};

export type PageFinalizationFields = {
  action: string | null;
  sectionSlug: string | null;
  revisionSlug: string | null;
  attemptGuid: string | null;
  result: string | null;
  commandResult: string | null;
  reason: string | null;
};

export type JournalRecord = {
  wireClass: WireClass;
  /** eval-candidates only; fixed by the response body, `unresolved` until then */
  resolution: EvalResolution | null;
  method: string;
  url: string;
  /** guid from the /activity_attempt/<guid> URL segment */
  attemptGuid: string | null;
  requestSeq: number;
  /**
   * Stamped at the OBSERVED response event, before any body read — body-parse
   * completion is not a wire event and never moves this stamp (§3.2/§3.3:
   * one strict order over observed events).
   */
  responseSeq: number | null;
  requestAt: number;
  responseAt: number | null;
  status: number | null;
  partInputs: unknown[] | null;
  /** creation responses: the server-minted fresh attempt guid */
  mintedGuid: string | null;
  actions: CheckActions | null;
  correct: boolean | null;
  llmFeedback: { text?: string } | null;
  finalization: PageFinalizationFields | null;
  parseError: string | null;
  /** null = outstanding (response event or body still pending); every audited record ends terminal */
  terminal: RecordTerminal | null;
  /** request started after the seal cutoff — marker only, never audited */
  postSeal: boolean;
};

export type FenceStamp = { seq: number; screenId: string; at: number };

/**
 * B4-STAMP: the permit kinds the driver may request. Declared HERE, in the
 * journal's own domain, rather than imported from the oracle — the issuer is
 * the authority on what it can issue, and the oracle's audited `Permit` type
 * is structurally compatible on purpose.
 */
export type IssuedPermitKind = 'check-click' | 'feedback-ack' | 'widget-button';

/**
 * B4-STAMP (MATERIAL): permits and readback-completed fences come from the
 * journal's monotonic domain, so they are strictly ordered against every wire
 * event. NO issuance method accepts a seq — the driver chooses WHEN to ask and
 * nothing else. `at` is informational; ordering is `seq` alone.
 */
export type PermitStamp = {
  kind: IssuedPermitKind;
  screenId: string;
  stepIndex: number;
  seq: number;
  at: number;
};

export type ReadbackStamp = { screenId: string; stepIndex: number; seq: number; at: number };

export type FinalizationFailure = { reason: FinalizationFailureReason };

/**
 * Positive audit evidence for the accepted-finalization freeze timeout
 * (§3.2 amendment, MER-5865 round 2): the lesson completed and its
 * finalization was accepted, but traffic never quiesced within the freeze
 * deadline — the run bails and SEALS. The oracle MUST map a snapshot carrying
 * this record to a violation; without it, fully settled informational traffic
 * could turn an ordinary bail into a zero-violation sealed audit.
 */
export type FreezeTimeout = { outstanding: number };

export type FinalizationStatus =
  | { kind: 'accepted' }
  | { kind: 'pending' }
  | { kind: 'rejected'; reason: FinalizationFailureReason };

export type JournalSnapshot = {
  state: 'sealed' | 'frozen';
  freezeFlavor: FreezeFlavor | null;
  finalizationFailure: FinalizationFailure | null;
  freezeTimeout: FreezeTimeout | null;
  sealIncomplete: boolean;
  sealCutoff: number | null;
  lessonEndSeq: number | null;
  records: JournalRecord[];
  postSealMarkers: number;
  fences: FenceStamp[];
  /**
   * B4-STAMP: what the journal ACTUALLY issued. The audit compares the
   * driver's runRecord against these — journal issuance alone would still let a
   * driver hand the oracle a permit it never obtained (contract threats 1/3).
   */
  permits: PermitStamp[];
  readbackFences: ReadbackStamp[];
};

/**
 * Pure journal core: an immutable-once-terminal event log over adaptive
 * evaluation traffic plus the page-lifecycle finalization, with ONE monotonic
 * seq domain shared by requests, response events, fences and the lesson-end
 * signal — so any two journal events have a strict order (spec §3.2/§3.3;
 * entry stamps must come from this domain, never a driver-local counter or
 * wall clock).
 *
 * Responses are two-phase: `ingestResponse` stamps the observed event
 * synchronously; `ingestResponseBody` fills the parsed fields later and
 * completes the record without touching the stamp. Terminal records never
 * mutate again, but their late response/failure events still count as
 * observed traffic for quiescence (§3.2: quiescence is judged over the
 * terminalized stream).
 *
 * The core never waits: freeze/seal orchestration (bounded waits, quiescence
 * intervals) belongs to AdaptiveJournalRecorder or a test harness, which
 * drives the same guarded transitions deterministically.
 */
export class AdaptiveJournalCore {
  private readonly log: JournalRecord[] = [];
  private readonly fenceLog: FenceStamp[] = [];
  private readonly permitLog: PermitStamp[] = [];
  private readonly readbackLog: ReadbackStamp[] = [];
  private seq = 0;
  private wireEvents = 0;
  private journalState: JournalState = 'armed';
  private lessonEnd: number | null = null;
  private terminalizing = false;
  private cutoff: number | null = null;
  private sealIncompleteFlag = false;
  private flavor: FreezeFlavor | null = null;
  private finalizationFailureRecord: FinalizationFailure | null = null;
  private freezeTimeoutRecord: FreezeTimeout | null = null;
  private correlation: RunCorrelation | null = null;

  constructor(private readonly now: () => number = Date.now) {}

  state(): JournalState {
    return this.journalState;
  }

  /** Bumps on every OBSERVED wire event — including events for records already terminal. */
  wireEventCount(): number {
    return this.wireEvents;
  }

  /** One-time, armed-only, stored by copy — audited semantics cannot be re-aimed later. */
  setRunCorrelation(correlation: RunCorrelation) {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot set correlation while ${this.journalState}`);
    }
    if (this.correlation !== null) {
      throw new Error('run correlation is already set');
    }
    this.correlation = { ...correlation };
  }

  /** Entry stamp for a screen visit, issued from the journal's own seq domain. */
  issueFence(screenId: string): FenceStamp {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot issue a fence while ${this.journalState}`);
    }
    const stamp: FenceStamp = { seq: ++this.seq, screenId, at: this.now() };
    this.fenceLog.push(stamp);
    // a copy: no retained reference can rewrite the stored fence after seal/freeze
    return { ...stamp };
  }

  /**
   * B4-STAMP: issue a permit for one step. Armed-only, like every other stamp —
   * a permit minted against a sealing/sealed/frozen journal would sit outside
   * the audited order. Returns a COPY so a retained reference cannot rewrite
   * the issued record after the seal.
   */
  issuePermit(kind: IssuedPermitKind, screenId: string, stepIndex: number): PermitStamp {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot issue a permit while ${this.journalState}`);
    }
    if (!Number.isInteger(stepIndex) || stepIndex < 0) {
      throw new Error(`permit step index must be a non-negative integer, got ${stepIndex}`);
    }
    const stamp: PermitStamp = { kind, screenId, stepIndex, seq: ++this.seq, at: this.now() };
    this.permitLog.push(stamp);
    return { ...stamp };
  }

  /**
   * B4-STAMP: the readback-completed fence — `savedBarrier`'s lower bound
   * (§3.5). Same domain as the wire events it bounds, so "the save landed after
   * readback finished" is a comparison of two journal seqs, never of clocks.
   */
  issueReadbackFence(screenId: string, stepIndex: number): ReadbackStamp {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot issue a readback fence while ${this.journalState}`);
    }
    if (!Number.isInteger(stepIndex) || stepIndex < 0) {
      throw new Error(`readback fence step index must be a non-negative integer, got ${stepIndex}`);
    }
    const stamp: ReadbackStamp = { screenId, stepIndex, seq: ++this.seq, at: this.now() };
    this.readbackLog.push(stamp);
    return { ...stamp };
  }

  permits(): PermitStamp[] {
    return structuredClone(this.permitLog);
  }

  readbackFences(): ReadbackStamp[] {
    return structuredClone(this.readbackLog);
  }

  noteLessonEnd() {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot note lesson end while ${this.journalState}`);
    }
    if (this.lessonEnd !== null) return;
    this.lessonEnd = ++this.seq;
  }

  lessonEndNoted(): boolean {
    return this.lessonEnd !== null;
  }

  ingestRequest(info: { method: string; url: string; postData: string | null }): number | null {
    if (this.journalState === 'sealed' || this.journalState === 'frozen') return null;
    const record = this.classify(info);
    if (!record) return null;
    this.wireEvents += 1;
    if (this.journalState === 'sealing') record.postSeal = true;
    if (this.terminalizing) record.terminal = 'unterminated';
    this.log.push(record);
    return this.log.length - 1;
  }

  /** Phase 1: the observed response event — synchronous seq stamp, no body yet. */
  ingestResponse(handle: number, status: number) {
    const record = this.log[handle];
    if (!record) return;
    if (this.journalState === 'sealed' || this.journalState === 'frozen') return;
    this.wireEvents += 1;
    if (record.terminal !== null || record.responseSeq !== null) return;
    record.responseSeq = ++this.seq;
    record.responseAt = this.now();
    record.status = status;
  }

  /** Phase 2: body-parse completion — fills parsed fields, never moves the stamp. */
  ingestResponseBody(handle: number, body: string | null) {
    const record = this.log[handle];
    if (!record) return;
    if (this.journalState === 'sealed' || this.journalState === 'frozen') return;
    if (record.terminal !== null || record.responseSeq === null) return;
    this.resolveResponse(record, body);
    record.terminal = 'completed';
  }

  /**
   * Terminal failure — legal BEFORE any response event or AFTER response
   * headers were observed (Playwright can emit `requestfailed` in place of
   * `requestfinished` when the body read dies). An already-stamped response
   * event keeps its seq and status; the record ends `failed`, never
   * `completed`.
   */
  ingestRequestFailed(handle: number) {
    const record = this.log[handle];
    if (!record) return;
    if (this.journalState === 'sealed' || this.journalState === 'frozen') return;
    this.wireEvents += 1;
    if (record.terminal !== null) return;
    if (record.responseSeq === null) {
      record.responseSeq = ++this.seq;
      record.responseAt = this.now();
    }
    record.terminal = 'failed';
    if (record.wireClass === 'eval-candidate') {
      record.parseError ??= 'request failed before a usable response';
    }
  }

  outstanding(): number {
    return this.log.filter((r) => r.terminal === null && !r.postSeal).length;
  }

  records(): JournalRecord[] {
    return structuredClone(this.log);
  }

  fences(): FenceStamp[] {
    return structuredClone(this.fenceLog);
  }

  /**
   * Acceptance contract (spec §3.2): correlated to THIS run's section slug,
   * revision slug and resource-attempt guid, parsed, 2xx, `result: success`
   * with `commandResult: success`. `already_submitted` is CATEGORICAL — a
   * settled correlated record carrying it rejects the run even when a
   * sibling finalization was accepted. Otherwise an accepted record wins
   * outright — even while a duplicate is still in flight; among rejections
   * a correlated record's reason outranks uncorrelated/malformed.
   */
  finalizationStatus(): FinalizationStatus {
    const finals = this.log.filter((r) => r.wireClass === 'page-finalization');
    // the categorical reason outranks acceptance across DUPLICATES too: a
    // settled correlated already_submitted invalidates the whole run (§3.2),
    // even when a sibling finalization was accepted
    const categorical = finals.some(
      (r) =>
        r.terminal === 'completed' &&
        r.parseError === null &&
        r.finalization != null &&
        this.correlatedFinalization(r.finalization) &&
        r.finalization.reason === 'already_submitted',
    );
    if (categorical) return { kind: 'rejected', reason: 'already_submitted' };
    for (const r of finals) {
      if (r.terminal !== 'completed' || r.parseError !== null) continue;
      const f = r.finalization;
      if (!f || !this.correlatedFinalization(f)) continue;
      const ok = r.status !== null && r.status >= 200 && r.status < 300;
      // `already_submitted` outranks acceptance categorically (§3.2). The real
      // server always pairs it with commandResult "failure"
      // (page_lifecycle_controller.ex:127-134) — this guard is for synthetic
      // journals and any future server shape, not a reachable Torus path.
      if (
        ok &&
        f.result === 'success' &&
        f.commandResult === 'success' &&
        f.reason !== 'already_submitted'
      ) {
        return { kind: 'accepted' };
      }
    }
    if (finals.length === 0 || finals.some((r) => r.terminal === null)) {
      return { kind: 'pending' };
    }
    return { kind: 'rejected', reason: this.aggregateRejection(finals) };
  }

  /**
   * The strongest rejection already SETTLED — for the acceptance-wait expiry:
   * a completed rejection must not be relabeled `missing` just because a
   * response-less duplicate was still in flight at the deadline. Null when no
   * finalization record has settled at all.
   */
  settledRejectionReason(): FinalizationFailureReason | null {
    const settled = this.log.filter(
      (r) => r.wireClass === 'page-finalization' && r.terminal !== null,
    );
    if (settled.length === 0) return null;
    return this.aggregateRejection(settled);
  }

  /**
   * Deterministic rejection precedence — duplicate finalizations that
   * disagree resolve by RANK, never by response order:
   * `already_submitted` (categorical violation) > correlated `failed` >
   * `uncorrelated` > `malformed`.
   */
  private aggregateRejection(finals: JournalRecord[]): FinalizationFailureReason {
    const RANK: Record<FinalizationFailureReason, number> = {
      already_submitted: 4,
      failed: 3,
      uncorrelated: 2,
      malformed: 1,
      missing: 0,
    };
    let rejection: FinalizationFailureReason | null = null;
    const note = (reason: FinalizationFailureReason) => {
      if (rejection === null || RANK[reason] > RANK[rejection]) rejection = reason;
    };
    for (const r of finals) {
      if (r.terminal === 'failed' || r.terminal === 'unterminated') {
        note('failed');
        continue;
      }
      const f = r.finalization;
      if (!f || r.parseError !== null) {
        note('malformed');
        continue;
      }
      if (!this.correlatedFinalization(f)) {
        note('uncorrelated');
        continue;
      }
      note(f.reason === 'already_submitted' ? 'already_submitted' : 'failed');
    }
    return rejection ?? 'malformed';
  }

  private correlatedFinalization(f: PageFinalizationFields): boolean {
    return (
      this.correlation !== null &&
      f.sectionSlug === this.correlation.sectionSlug &&
      f.revisionSlug === this.correlation.revisionSlug &&
      f.attemptGuid === this.correlation.resourceAttemptGuid
    );
  }

  /**
   * Persistent terminalization mode (spec §3.2, completed-failure flavor):
   * every outstanding request gets a terminal `unterminated` record NOW, and
   * from this point every newly observed request is terminal-recorded on
   * observation — an arrival can restart quiescence but never hang the freeze.
   */
  enterTerminalization(reason: FinalizationFailureReason) {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot terminalize while ${this.journalState}`);
    }
    if (this.lessonEnd === null) {
      throw new Error('terminalization requires the lesson-end signal first');
    }
    if (this.terminalizing) return;
    this.terminalizing = true;
    this.finalizationFailureRecord = { reason };
    for (const r of this.log) {
      if (r.terminal === null) r.terminal = 'unterminated';
    }
  }

  isTerminalizing(): boolean {
    return this.terminalizing;
  }

  /**
   * Positive evidence that the accepted-path freeze deadline expired — the
   * bail that follows seals, and the sealed snapshot must still map to a
   * violation (§3.2: an ordinary bail can never audit to zero violations).
   */
  markFreezeTimeout() {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot record a freeze timeout while ${this.journalState}`);
    }
    if (this.lessonEnd === null) {
      throw new Error('a freeze timeout requires the lesson-end signal first');
    }
    this.freezeTimeoutRecord ??= { outstanding: this.outstanding() };
  }

  /**
   * Guarded freeze transitions — the caller owns the quiescence interval;
   * these re-validate every precondition so a freeze can never race an
   * outstanding request (spec §3.2 ordering).
   */
  markFrozenAccepted() {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot freeze while ${this.journalState}`);
    }
    if (this.lessonEnd === null) throw new Error('freeze requires the lesson-end signal');
    if (this.terminalizing) {
      throw new Error('terminalized journal must take the completed-failure freeze');
    }
    const finalization = this.finalizationStatus();
    if (finalization.kind !== 'accepted') {
      throw new Error(`freeze requires an accepted finalization, saw ${finalization.kind}`);
    }
    if (this.outstanding() > 0) {
      throw new Error(`freeze with ${this.outstanding()} outstanding request(s)`);
    }
    this.journalState = 'frozen';
    this.flavor = 'accepted';
  }

  markFrozenCompletedFailure() {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot freeze while ${this.journalState}`);
    }
    if (!this.terminalizing || this.finalizationFailureRecord === null) {
      throw new Error('completed-failure freeze requires terminalization first');
    }
    if (this.outstanding() > 0) {
      throw new Error(`freeze with ${this.outstanding()} outstanding request(s)`);
    }
    this.journalState = 'frozen';
    this.flavor = 'completed-failure';
  }

  /**
   * Atomic seal (spec §3.2): fixes the immutable cutoff; audited-set
   * membership is `requestSeq <= cutoff` alone. Member responses arriving
   * during `sealing` complete in place; requests starting after the cutoff
   * are post-seal markers and never enter the audited set.
   */
  beginSeal(): number {
    if (this.journalState !== 'armed') {
      throw new Error(`journal cannot seal while ${this.journalState}`);
    }
    this.journalState = 'sealing';
    this.cutoff = this.seq;
    return this.cutoff;
  }

  /**
   * `seal_incomplete` is DERIVED, never asserted by the caller: the snapshot
   * is complete exactly when every member record reached a terminal state
   * before the seal closed (spec §3.2 — a complete snapshot cannot contain an
   * `unterminated` member).
   */
  finishSeal() {
    if (this.journalState !== 'sealing') {
      throw new Error(`journal cannot finish a seal while ${this.journalState}`);
    }
    const members = this.log.filter((r) => !r.postSeal && r.requestSeq <= (this.cutoff as number));
    this.sealIncompleteFlag = members.some((r) => r.terminal === null);
    for (const r of this.log) {
      if (r.terminal === null) r.terminal = 'unterminated';
    }
    this.journalState = 'sealed';
  }

  /** Frozen or sealed only — the audit input; sealed audits see members only. */
  snapshot(): JournalSnapshot {
    if (this.journalState !== 'sealed' && this.journalState !== 'frozen') {
      throw new Error(`no snapshot of a journal that is ${this.journalState}`);
    }
    const audited =
      this.journalState === 'sealed'
        ? this.log.filter((r) => !r.postSeal && r.requestSeq <= (this.cutoff as number))
        : this.log;
    return structuredClone({
      state: this.journalState,
      freezeFlavor: this.flavor,
      finalizationFailure: this.finalizationFailureRecord,
      freezeTimeout: this.freezeTimeoutRecord,
      sealIncomplete: this.sealIncompleteFlag,
      sealCutoff: this.cutoff,
      lessonEndSeq: this.lessonEnd,
      records: audited as JournalRecord[],
      postSealMarkers: this.log.filter((r) => r.postSeal).length,
      fences: this.fenceLog as FenceStamp[],
      permits: this.permitLog as PermitStamp[],
      readbackFences: this.readbackLog as ReadbackStamp[],
    });
  }

  private classify(info: {
    method: string;
    url: string;
    postData: string | null;
  }): JournalRecord | null {
    const save = info.method === 'PATCH' ? SAVE_URL.exec(info.url) : null;
    const evaluation = info.method === 'PUT' ? EVAL_URL.exec(info.url) : null;
    const creation = info.method === 'POST' ? EVAL_URL.exec(info.url) : null;
    const pageFinal = info.method === 'POST' && PAGE_LIFECYCLE_URL.test(info.url);

    let wireClass: WireClass;
    let attemptGuid: string | null = null;
    if (pageFinal) {
      wireClass = 'page-finalization';
    } else if (save) {
      wireClass = 'save';
      attemptGuid = save[1];
    } else if (creation) {
      wireClass = 'creation';
      attemptGuid = creation[1];
    } else if (evaluation) {
      wireClass = 'eval-candidate';
      attemptGuid = evaluation[1];
    } else {
      return null;
    }

    const record: JournalRecord = {
      wireClass,
      resolution: wireClass === 'eval-candidate' ? 'unresolved' : null,
      method: info.method,
      url: info.url,
      attemptGuid,
      requestSeq: ++this.seq,
      responseSeq: null,
      requestAt: this.now(),
      responseAt: null,
      status: null,
      partInputs: null,
      mintedGuid: null,
      actions: null,
      correct: null,
      llmFeedback: null,
      finalization: null,
      parseError: null,
      terminal: null,
      postSeal: false,
    };

    if (wireClass === 'save' || wireClass === 'eval-candidate') {
      const body = parseJson(info.postData) as { partInputs?: unknown } | null;
      record.partInputs = Array.isArray(body?.partInputs) ? body.partInputs : null;
      if (record.partInputs === null) {
        record.parseError = 'request body carries no partInputs array';
      }
    } else if (wireClass === 'page-finalization') {
      const body = parseJson(info.postData) as Record<string, unknown> | null;
      if (body === null) {
        record.parseError = 'unreadable page-finalization request body';
      } else {
        if (body.action !== 'finalize') return null;
        record.finalization = {
          action: asString(body.action),
          sectionSlug: asString(body.section_slug),
          revisionSlug: asString(body.revision_slug),
          attemptGuid: asString(body.attempt_guid),
          result: null,
          commandResult: null,
          reason: null,
        };
      }
    }
    return record;
  }

  private resolveResponse(record: JournalRecord, body: string | null) {
    if (record.wireClass === 'creation') {
      const parsed = parseJson(body) as { attemptState?: { attemptGuid?: unknown } } | null;
      const minted = parsed?.attemptState?.attemptGuid;
      record.mintedGuid = typeof minted === 'string' ? minted : null;
      return;
    }
    if (record.wireClass === 'page-finalization') {
      const parsed = parseJson(body) as Record<string, unknown> | null;
      if (parsed === null) {
        record.parseError ??= 'unreadable page-finalization response';
        return;
      }
      record.finalization = {
        ...(record.finalization ?? {
          action: null,
          sectionSlug: null,
          revisionSlug: null,
          attemptGuid: null,
          result: null,
          commandResult: null,
          reason: null,
        }),
        result: asString(parsed.result),
        commandResult: asString(parsed.commandResult),
        reason: asString(parsed.reason),
      };
      return;
    }
    if (record.wireClass !== 'eval-candidate') return;
    const status = record.status as number;
    if (status < 200 || status >= 300) {
      record.parseError ??= `evaluation candidate returned status ${status}`;
      return;
    }
    const parsed = parseJson(body) as {
      actions?: CheckActions;
      type?: string;
      llm_feedback?: { text?: string };
    } | null;
    if (parsed === null) {
      record.parseError ??= 'unreadable evaluation response';
      return;
    }
    const actions = parsed.actions;
    if (actions && typeof actions.correct === 'boolean') {
      record.resolution = 'evaluation';
      record.actions = actions;
      record.correct = actions.correct;
      record.llmFeedback = parsed.llm_feedback ?? null;
    } else if (parsed.type === 'success') {
      record.resolution = 'activity-finalize';
    } else {
      record.parseError ??= 'evaluation response carries no boolean actions.correct';
    }
  }
}

function parseJson(raw: string | null): unknown {
  if (raw === null) return null;
  try {
    const parsed: unknown = JSON.parse(raw);
    return parsed !== null && typeof parsed === 'object' ? parsed : null;
  } catch {
    return null;
  }
}

function asString(v: unknown): string | null {
  return typeof v === 'string' ? v : null;
}

/**
 * Playwright adapter: attaches the core to a live page BEFORE the deck loads
 * and owns the freeze/seal waits. Detach lives in the spec fixture's
 * `finally` — an early exception seals instead of dangling (spec §3.2).
 */
export class AdaptiveJournalRecorder {
  readonly core: AdaptiveJournalCore;
  private readonly handles = new Map<Request, number>();
  private attached = false;

  constructor(
    private readonly page: Page,
    core?: AdaptiveJournalCore,
  ) {
    this.core = core ?? new AdaptiveJournalCore();
  }

  private readonly onRequest = (request: Request) => {
    const handle = this.core.ingestRequest({
      method: request.method(),
      url: request.url(),
      postData: request.postData(),
    });
    if (handle !== null) this.handles.set(request, handle);
  };

  private readonly onResponse = (response: Response) => {
    const handle = this.handles.get(response.request());
    if (handle === undefined) return;
    // the observed event is stamped synchronously; only the body fill is
    // async. The handle stays registered until the record is TERMINAL —
    // Playwright may emit `requestfailed` after response headers, and that
    // failure must reach the same record instead of finding no handle. A
    // body-read rejection is itself the failure signal, never a completion.
    this.core.ingestResponse(handle, response.status());
    void response
      .text()
      .then((body) => {
        this.handles.delete(response.request());
        this.core.ingestResponseBody(handle, body);
      })
      .catch(() => {
        this.handles.delete(response.request());
        this.core.ingestRequestFailed(handle);
      });
  };

  private readonly onRequestFailed = (request: Request) => {
    const handle = this.handles.get(request);
    if (handle === undefined) return;
    this.handles.delete(request);
    this.core.ingestRequestFailed(handle);
  };

  attach() {
    if (this.attached) throw new Error('journal recorder is already attached');
    this.page.on('request', this.onRequest);
    this.page.on('response', this.onResponse);
    this.page.on('requestfailed', this.onRequestFailed);
    this.attached = true;
  }

  detach() {
    this.page.off('request', this.onRequest);
    this.page.off('response', this.onResponse);
    this.page.off('requestfailed', this.onRequestFailed);
    this.attached = false;
  }

  /**
   * Freeze orchestration, in spec §3.2 order. Accepted path: bounded wait for
   * finalization acceptance → drain + FULL quiescence interval as one
   * retrying loop (a post-zero arrival restarts the loop, it never turns a
   * valid lifecycle into an exception) → guarded freeze. On acceptance
   * expiry/rejection: terminalization, then quiescence over the terminalized
   * stream → completed-failure freeze; the overall deadline bounds it — a
   * request stream with sub-interval gaps delays but can never hang the
   * freeze, because terminalization keeps outstanding at zero.
   *
   * An ACCEPTED finalization whose surrounding traffic never quiesces within
   * the deadline THROWS instead of freezing or inventing a finalization
   * failure (§3.2's failure union describes finalization outcomes only) —
   * the spec fixture's failure path seals, and the sealed snapshot carries
   * the evidence.
   */
  async awaitFreeze(
    opts: { finalizationTimeoutMs?: number; freezeTimeoutMs?: number; quiescenceMs?: number } = {},
  ): Promise<FreezeFlavor> {
    const finalizationTimeoutMs = opts.finalizationTimeoutMs ?? 15_000;
    const freezeTimeoutMs = opts.freezeTimeoutMs ?? 60_000;
    const quiescenceMs = opts.quiescenceMs ?? 500;
    if (!this.core.lessonEndNoted()) {
      throw new Error('awaitFreeze requires the lesson-end signal first');
    }

    // freezeTimeoutMs is the OVERALL bound on this call: every phase spends
    // from the same deadline, and no full quiescence interval is started
    // that could not finish inside it
    const start = Date.now();
    const freezeDeadline = start + freezeTimeoutMs;
    const finalizationDeadline = Math.min(start + finalizationTimeoutMs, freezeDeadline);
    let accepted = false;
    for (;;) {
      const status = this.core.finalizationStatus();
      if (status.kind === 'accepted') {
        accepted = true;
        break;
      }
      if (status.kind === 'rejected') {
        this.core.enterTerminalization(status.reason);
        break;
      }
      if (Date.now() >= finalizationDeadline) {
        // a rejection that already SETTLED is the evidence; `missing` only
        // when nothing settled — a response-less duplicate cannot erase a
        // completed rejection
        this.core.enterTerminalization(this.core.settledRejectionReason() ?? 'missing');
        break;
      }
      await sleep(50);
    }

    if (accepted) {
      for (;;) {
        // acceptance is NOT latched (§3.2): a correlated duplicate settling
        // as categorical DURING the drain flips the whole run — re-evaluate
        // on every pass and immediately before the freeze, so the late
        // rejection becomes an audited completed-failure outcome instead of
        // an exception with no typed finalization-failure record
        const recheck = this.core.finalizationStatus();
        if (recheck.kind === 'rejected') {
          this.core.enterTerminalization(recheck.reason);
          break;
        }
        if (freezeDeadline - Date.now() < quiescenceMs) {
          this.core.markFreezeTimeout();
          throw new Error(
            `finalization accepted but traffic never quiesced within ${freezeTimeoutMs}ms — ` +
              `${this.core.outstanding()} outstanding; seal instead`,
          );
        }
        if (this.core.outstanding() > 0) {
          await sleep(50);
          continue;
        }
        const seen = this.core.wireEventCount();
        await sleep(quiescenceMs);
        if (this.core.wireEventCount() === seen && this.core.outstanding() === 0) {
          const final = this.core.finalizationStatus();
          if (final.kind === 'rejected') {
            this.core.enterTerminalization(final.reason);
            break;
          }
          this.core.markFrozenAccepted();
          return 'accepted';
        }
      }
    }

    for (;;) {
      const remaining = freezeDeadline - Date.now();
      if (remaining <= 0) {
        this.core.markFrozenCompletedFailure();
        return 'completed-failure';
      }
      const seen = this.core.wireEventCount();
      await sleep(Math.min(quiescenceMs, remaining));
      if (this.core.wireEventCount() === seen || Date.now() >= freezeDeadline) {
        this.core.markFrozenCompletedFailure();
        return 'completed-failure';
      }
    }
  }

  /** Failure-path seal: cutoff now, bounded settle for members, then sealed. */
  async seal(settleTimeoutMs = 10_000) {
    this.core.beginSeal();
    const deadline = Date.now() + settleTimeoutMs;
    while (this.core.outstanding() > 0 && Date.now() < deadline) {
      await sleep(50);
    }
    this.core.finishSeal();
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
