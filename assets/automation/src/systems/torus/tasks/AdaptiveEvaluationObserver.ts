import { Page, Request, Response } from '@playwright/test';
import { AttemptCreation, CheckActions, EvaluationRecord } from '@tasks/AdaptiveStrictContract';

const EVAL_URL = /\/activity_attempt\/([^/?#]+)(?:[?#]|$)/;
const SAVE_URL = /\/activity_attempt\/([^/?#]+)\/active(?:[?#]|$)/;

/**
 * Multi-event collector for adaptive evaluation traffic. Unlike
 * page.waitForResponse — which resolves with a single matched response —
 * this stays attached through the whole screen transition, so a duplicate
 * submission arriving after the first response is recorded, not lost.
 *
 * Attribution is by SCREEN, not attempt guid: the deck rotates the attempt
 * when a check is incorrect, does not navigate away, and attempts remain
 * (triggerCheck.ts:424), so one screen's evaluations can legally span
 * several guids. The submitted part paths carry the stable `<sequenceId>|stage...`
 * prefix, which is the same identity the manifest declares. Requests whose
 * paths name a different screen — e.g. a late submission from the previous
 * screen — are kept separately and never attributed to this one.
 *
 * Finalize saves PUT the same URL shape as evaluations; they are told apart
 * by the response body (evaluations carry `actions`, finalizes a bare
 * `type: "success"`) and excluded from `evaluations()`.
 */
export class AdaptiveEvaluationObserver {
  private readonly own: EvaluationRecord[] = [];
  private readonly foreign: EvaluationRecord[] = [];
  private readonly pending = new Map<Request, EvaluationRecord>();
  private readonly creationRecords: AttemptCreation[] = [];
  private readonly pendingCreations = new Map<Request, AttemptCreation>();
  private seq = 0;
  private armed = false;

  constructor(
    private readonly page: Page,
    private readonly screenId: string,
  ) {}

  private readonly onRequest = (request: Request) => {
    const creation = request.method() === 'POST' ? EVAL_URL.exec(request.url()) : null;
    if (creation) {
      const record: AttemptCreation = {
        targetGuid: creation[1],
        newGuid: null,
        requestSeq: ++this.seq,
        responseSeq: null,
        status: null,
        parsed: false,
      };
      this.creationRecords.push(record);
      this.pendingCreations.set(request, record);
      return;
    }
    const save = request.method() === 'PATCH' ? SAVE_URL.exec(request.url()) : null;
    const evaluation = request.method() === 'PUT' ? EVAL_URL.exec(request.url()) : null;
    const match = save ?? evaluation;
    if (!match) return;

    const record: EvaluationRecord = {
      attemptGuid: match[1],
      screenId: null,
      otherScreenIds: [],
      llmFeedback: null,
      kind: save ? 'save' : 'unknown',
      url: request.url(),
      partInputs: null,
      requestAt: Date.now(),
      responseAt: null,
      requestSeq: ++this.seq,
      responseSeq: null,
      status: null,
      actions: null,
      correct: null,
      parseError: null,
      parsed: false,
    };
    let ownable = false;
    try {
      const body = request.postDataJSON() as { partInputs?: unknown } | null;
      record.partInputs = Array.isArray(body?.partInputs) ? body.partInputs : null;
      if (record.partInputs === null)
        record.parseError = 'request body carries no partInputs array';
      const ids = submittedScreenIds(record.partInputs);
      record.screenId = ids.find((id) => id === this.screenId) ?? ids[0] ?? null;
      // a mixed submission is attributed here but its other prefixes are
      // preserved: the walk fails the screen if any of them belongs to a
      // DIFFERENT manifest screen (layer parents are not manifest screens)
      record.otherScreenIds = ids.filter((id) => id !== this.screenId);
      // a screen with no answerable parts submits empty partInputs — no
      // paths to attribute by. Late submissions from answered screens always
      // carry paths, so a pathless evaluation belongs to the current screen.
      ownable = record.screenId === this.screenId || ids.length === 0;
    } catch (e) {
      record.parseError = `unreadable request body: ${(e as Error).message}`;
    }
    (ownable ? this.own : this.foreign).push(record);
    this.pending.set(request, record);
  };

  private readonly onResponse = (response: Response) => {
    const creation = this.pendingCreations.get(response.request());
    if (creation) {
      this.pendingCreations.delete(response.request());
      creation.responseSeq = ++this.seq;
      creation.status = response.status();
      void response
        .json()
        .then((body: { attemptState?: { attemptGuid?: unknown } }) => {
          const minted = body?.attemptState?.attemptGuid;
          creation.newGuid = typeof minted === 'string' ? minted : null;
        })
        .catch(() => undefined)
        .finally(() => {
          creation.parsed = true;
        });
      return;
    }
    const record = this.pending.get(response.request());
    if (!record) return;
    this.pending.delete(response.request());
    record.responseAt = Date.now();
    record.responseSeq = ++this.seq;
    record.status = response.status();
    if (record.kind === 'save') {
      record.parsed = true;
      return;
    }
    void response
      .json()
      .then((body: { actions?: CheckActions; type?: string; llm_feedback?: { text?: string } }) => {
        const actions = body?.actions;
        if (actions && typeof actions.correct === 'boolean') {
          record.kind = 'evaluation';
          record.actions = actions;
          record.correct = actions.correct;
          // the deck opens feedback for server-generated LLM text too, so the
          // transition derivation needs it (DeckLayoutFooter:546-558)
          record.llmFeedback = body.llm_feedback ?? null;
        } else if (body?.type === 'success') {
          record.kind = 'finalize';
        } else {
          record.parseError ??= 'evaluation response carries no boolean actions.correct';
        }
      })
      .catch((e: Error) => {
        record.parseError ??= `unreadable evaluation response: ${e.message}`;
      })
      .finally(() => {
        record.parsed = true;
      });
  };

  arm() {
    if (this.armed) throw new Error('evaluation observer is already armed');
    this.page.on('request', this.onRequest);
    this.page.on('response', this.onResponse);
    this.armed = true;
  }

  dispose() {
    this.page.off('request', this.onRequest);
    this.page.off('response', this.onResponse);
    this.armed = false;
  }

  /**
   * This screen's evaluations. Saves and finalizes are excluded; a record
   * whose response has not been parsed yet is still `unknown` and counts,
   * so callers that need a stable count must `settle()` first.
   */
  evaluations(): EvaluationRecord[] {
    return this.own.filter((r) => r.kind !== 'finalize' && r.kind !== 'save');
  }

  /**
   * Resolve once every observed request has a parsed response, so counts no
   * longer move and an in-flight finalize can no longer masquerade as an
   * evaluation. Returns false if traffic is still outstanding at the deadline.
   */
  async settle(timeoutMs = 10_000): Promise<boolean> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const outstanding =
        this.pending.size +
        this.pendingCreations.size +
        [...this.own, ...this.foreign].filter((r) => !r.parsed).length +
        this.creationRecords.filter((c) => !c.parsed).length;
      if (outstanding === 0) return true;
      if (Date.now() >= deadline) return false;
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
  }

  /** This screen's deferred PATCH saves — the deck persisting propagated part state. */
  saves(): EvaluationRecord[] {
    return this.own.filter((r) => r.kind === 'save');
  }

  /** Observed attempt rotations — POST mints of fresh attempts, any screen. */
  creations(): AttemptCreation[] {
    return this.creationRecords;
  }

  /** Evaluations whose submitted paths name a different screen, or none at all. */
  foreignEvaluations(): EvaluationRecord[] {
    return this.foreign.filter((r) => r.kind !== 'save');
  }

  async waitForEvaluation(expectedCount: number, timeoutMs: number): Promise<EvaluationRecord> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const parsed = this.evaluations().filter((r) => r.parsed);
      if (parsed.length >= expectedCount) return parsed[expectedCount - 1];
      if (Date.now() >= deadline) {
        throw new Error(
          `no evaluation ${expectedCount} for screen ${this.screenId} within ${timeoutMs}ms ` +
            `(own: ${this.own.length}, foreign: ${this.foreign.length})`,
        );
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
  }
}

function submittedScreenIds(partInputs: unknown[] | null): string[] {
  if (!partInputs) return [];
  const ids = new Set<string>();
  for (const part of partInputs) {
    const response = (part as { response?: Record<string, unknown> | null })?.response;
    if (!response || typeof response !== 'object') continue;
    // evaluation PUTs nest the part map under `input`; PATCH saves inline it
    const input =
      response.input && typeof response.input === 'object'
        ? (response.input as Record<string, unknown>)
        : response;
    for (const item of Object.values(input)) {
      const entry = item as { path?: unknown } | null;
      if (entry && typeof entry.path === 'string' && entry.path.includes('|')) {
        ids.add(entry.path.split('|')[0]);
      }
    }
  }
  return Array.from(ids);
}
