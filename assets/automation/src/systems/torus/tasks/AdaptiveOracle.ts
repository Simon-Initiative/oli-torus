import {
  AttributedRecord,
  VisitStamp,
  attribute,
  extractSubmittedPrefixes,
  resolveProvenance,
} from '@tasks/AdaptiveAttribution';
import { FinalizationFailureReason, JournalRecord, JournalSnapshot } from '@tasks/AdaptiveJournal';
import {
  AdaptiveManifest,
  GradingExpectation,
  ScreenDefinition,
  evaluatePredicate,
} from '@tasks/AdaptiveManifest';
import {
  CheckResultEvent,
  PlannedTransition,
  planTransition,
  transitionNavigates,
} from '@tasks/AdaptiveTransitionPlanner';

/**
 * Pure audit oracle (spec §3.5): `auditRun(manifest, runRecord, snapshot)`
 * replays the transition planner over every owned evaluation, compares the
 * driver's RECORDED plan against the replay, and re-states the full
 * invariant inventory. It never waits and never touches a page — synthetic
 * journals and captured journals audit identically.
 *
 * Violations are REDACTED BY CONSTRUCTION (§3.7): `Violation` carries a
 * closed, typed fact set — identifiers, seqs, counts, kinds and booleans.
 * There is no free-form message field; the reporter owns every template.
 */

export type RunVisit = VisitStamp & { resourceId: number };

export type PermitKind = 'check-click' | 'feedback-ack' | 'widget-button';
export type Permit = { kind: PermitKind; screenId: string; stepIndex: number; seq: number };

/** Closed union (§3.2) — an unlisted failure mode is a spec bug, not an extension point. */
export type OperationFailureKind =
  | 'identity-unresolved'
  | 'readiness-timeout'
  | 'answer-failed'
  | 'readback-failed'
  | 'barrier-timeout'
  | 'check-click-no-effect'
  | 'feedback-never-opened'
  | 'ack-no-effect'
  | 'widget-button-unavailable'
  | 'navigation-timeout';

export type OperationFailure = {
  kind: OperationFailureKind;
  /** resolved screen, or null for identity-unresolved */
  screenId: string | null;
  /** attribution rule (§3.2): the EXPECTED scenario step by position */
  expectedStepIndex: number;
};

export type StepReceipt = {
  stepIndex: number;
  screenId: string;
  directive: string;
  matcher: 'local' | 'cross_screen';
  expectations: GradingExpectation[];
  /** paths that must appear in a PATCH save inside the barrier window */
  savedBarrierPrefixes?: string[];
  /** journal-seq stamp when answer + readback completed — the barrier's lower bound */
  readbackCompletedSeq?: number;
};

/** The driver's ONLINE transition decision for one evaluation (§3.5 replay agreement). */
export type RecordedPlan = {
  stepIndex: number;
  /** requestSeq of the evaluation this plan was derived from */
  evaluationSeq: number;
  plan: PlannedTransition;
};

export type RunRecord = {
  visits: RunVisit[];
  permits: Permit[];
  receipts: StepReceipt[];
  operationFailures: OperationFailure[];
  /** recorded online plans; absent entries are audited as missing (§3.5) */
  plans?: RecordedPlan[];
};

export type ViolationCode =
  | 'route-shape'
  | 'resource-id-inconsistent'
  | 'evaluation-unusable'
  | 'evaluation-no-causal-edge'
  | 'evaluation-count'
  | 'navigation-sequence'
  | 'verdict-not-correct'
  | 'receipt-missing'
  | 'receipt-mismatch'
  | 'payload-mismatch'
  | 'attempt-anchor'
  | 'saved-barrier'
  | 'plan-illegal'
  | 'plan-divergence'
  | 'permit-mismatch'
  | 'obligation-unfulfilled'
  | 'unresolved-candidate-owned'
  | 'provenance-contamination'
  | 'lineage'
  | 'pre-entry-illegal'
  | 'terminal-obligation'
  | 'freeze-timeout'
  | 'seal-without-evidence'
  | 'request-failed'
  | 'operation-failure';

/**
 * Closed fact set (§3.7): every field is an identifier, seq, count, kind or
 * boolean. No field exists that could carry a submitted value; the reporter's
 * templates below are the only render path.
 */
export type ViolationFacts = {
  seq?: number;
  seq2?: number;
  entrySeq?: number;
  lowerSeq?: number | null;
  upperSeq?: number | null;
  count?: number;
  expectedCount?: number;
  visitIndex?: number;
  declaredCount?: number;
  guid?: string | null;
  expectedGuid?: string;
  dependencyId?: string;
  otherScreenId?: string;
  expectedRef?: string;
  prefix?: string;
  pathLabel?: string;
  permitKind?: PermitKind;
  failureKind?: OperationFailureKind;
  planKind?: PlannedTransition['kind'];
  planKind2?: PlannedTransition['kind'];
  target?: string;
  verdict?: boolean | null;
  expectedVerdict?: boolean;
  reason?: FinalizationFailureReason | 'unknown';
  detail?:
    | 'beyond-scenario'
    | 'screen-mismatch'
    | 'undeclared-screen'
    | 'count-mismatch'
    | 'no-response'
    | 'unstable-dependency'
    | 'missing-recorded-plan'
    | 'screen'
    | 'expectations'
    | 'matcher'
    | 'dependency-unvisited'
    | 'duplicate'
    | 'outside-window'
    | 'unused'
    | 'wrong-role'
    | 'no-lesson-end'
    | 'finalization-misbehaved'
    | 'no-lesson-completion'
    | 'no-successor'
    | 'target-not-next'
    | 'no-ack'
    | 'no-second-evaluation'
    | 'wrong-successor-target'
    | 'ambiguous-part-order'
    | 'ambiguous-attempt-order'
    | 'missing'
    | 'beyond-route'
    | 'incorrect-singleton'
    | 'non-navigating-singleton'
    | 'rotation-unproven'
    | 'too-many';
  status?: number | null;
  terminal?: JournalRecord['terminal'];
  outstanding?: number;
  resourceIdFrom?: number;
  resourceIdTo?: number;
  mintObserved?: boolean;
};

export type Violation = {
  code: ViolationCode;
  screenId: string | null;
  stepIndex: number | null;
  facts: ViolationFacts;
};

const violation = (
  code: ViolationCode,
  screenId: string | null,
  stepIndex: number | null,
  facts: ViolationFacts = {},
): Violation => ({ code, screenId, stepIndex, facts });

type OwnedEvaluation = { record: JournalRecord; attributed: AttributedRecord };

const usable = (r: JournalRecord): boolean =>
  r.resolution === 'evaluation' &&
  r.status !== null &&
  r.status >= 200 &&
  r.status < 300 &&
  r.responseSeq !== null &&
  r.parseError === null &&
  r.actions !== null &&
  typeof r.correct === 'boolean';

const resultsOf = (r: JournalRecord): CheckResultEvent[] =>
  (r.actions?.results ?? []) as CheckResultEvent[];

const samePlan = (a: PlannedTransition, b: PlannedTransition): boolean =>
  JSON.stringify(a) === JSON.stringify(b);

export function auditRun(
  manifest: AdaptiveManifest,
  runRecord: RunRecord,
  snapshot: JournalSnapshot,
): Violation[] {
  const violations: Violation[] = [];
  const { visits, permits, receipts, operationFailures } = runRecord;
  const recordedPlans = runRecord.plans ?? [];
  const screensById = new Map(manifest.screens.map((s) => [s.id, s]));
  const manifestIds = new Set(manifest.screens.map((s) => s.id));

  // ---- restricted-invariant scope (§3.2 failure-state matrix) -------------
  const sealedRun = snapshot.state === 'sealed';
  const fullJournalAudit = !sealedRun || !snapshot.sealIncomplete;
  const windowClosed = (i: number): boolean => !sealedRun || i < visits.length - 1;
  const ownedByVisit = new Map<number, OwnedEvaluation[]>();
  // settled = TERMINAL, not successful (§3.2): a failed candidate is a settled
  // member — it already reports as positive evidence; suppressing the window's
  // cardinality/absence conclusions for it would hide the rest
  const windowSettled = (i: number): boolean =>
    (ownedByVisit.get(i) ?? []).every((e) => e.record.terminal !== null);
  const fullWindowAudit = (i: number): boolean =>
    fullJournalAudit && windowClosed(i) && windowSettled(i);

  // ---- attribution: ownership + lineage (§3.3) ----------------------------
  const { attributed, violations: lineageViolations } = attribute(snapshot, visits);
  for (const lv of lineageViolations) {
    violations.push(
      violation('lineage', lv.screenId, null, { guid: lv.attemptGuid, seq: lv.requestSeq }),
    );
  }
  for (const a of attributed) {
    if (a.ownerIndex === null) continue;
    const list = ownedByVisit.get(a.ownerIndex) ?? [];
    if (a.record.wireClass === 'eval-candidate') list.push({ record: a.record, attributed: a });
    ownedByVisit.set(a.ownerIndex, list);
  }

  // ---- operation failures are positive evidence (§3.2) — and their
  // attribution is VALIDATED, never trusted: identity-unresolved derives its
  // reported screen from the expected scenario position; a resolved failure
  // must name a manifest screen; a contradictory or out-of-domain record is
  // itself a violation
  for (const failure of operationFailures) {
    const inScenario =
      Number.isInteger(failure.expectedStepIndex) &&
      failure.expectedStepIndex >= 0 &&
      failure.expectedStepIndex < manifest.scenario.length;
    const expectedRef = inScenario ? manifest.scenario[failure.expectedStepIndex].screen_ref : null;
    const reportScreen = failure.kind === 'identity-unresolved' ? expectedRef : failure.screenId;
    violations.push(
      violation('operation-failure', reportScreen, failure.expectedStepIndex, {
        failureKind: failure.kind,
      }),
    );
    if (!inScenario) {
      violations.push(
        violation('operation-failure', reportScreen, failure.expectedStepIndex, {
          detail: 'beyond-route',
        }),
      );
    }
    // §3.2 attribution: a RESOLVED failure names the OBSERVED screen — it
    // must match the visit actually holding its expected step (a diverged
    // route makes the visit, not the scenario, the truth); scenario-derived
    // attribution is reserved for identity-unresolved. A resolved failure
    // for a step with no visit at all is contradictory evidence.
    const visitAtStep = visits[failure.expectedStepIndex];
    const contradictory =
      failure.kind === 'identity-unresolved'
        ? failure.screenId !== null
        : failure.screenId === null ||
          visitAtStep === undefined ||
          failure.screenId !== visitAtStep.screenId;
    if (contradictory) {
      violations.push(
        violation('operation-failure', reportScreen, failure.expectedStepIndex, {
          detail: 'screen-mismatch',
          otherScreenId: failure.screenId ?? undefined,
        }),
      );
    }
  }

  // ---- §3.5 strictness table: other failed/aborted requests are REPORTED —
  // a failed save or creation can never silently coexist with a clean audit
  // (it is also barred from every commit/causal proof by the terminal checks)
  for (const r of snapshot.records) {
    if (r.terminal !== 'failed' && r.terminal !== 'unterminated') continue;
    if (r.wireClass === 'eval-candidate' || r.wireClass === 'page-finalization') continue;
    violations.push(
      violation('request-failed', null, null, {
        seq: r.requestSeq,
        status: r.status,
        terminal: r.terminal,
      }),
    );
  }

  // ---- freeze-timeout record (§3.2 amendment) ------------------------------
  if (snapshot.freezeTimeout !== null) {
    violations.push(
      violation('freeze-timeout', null, null, {
        outstanding: snapshot.freezeTimeout.outstanding,
      }),
    );
  }

  // ---- run-record domain sweep: evidence naming a step with no visit is
  // positive evidence of a broken driver — the per-step loops would silently
  // skip it (§3.5 inventory is one-to-one over the VISITED domain)
  const inVisitDomain = (stepIndex: number): boolean =>
    Number.isInteger(stepIndex) && stepIndex >= 0 && stepIndex < visits.length;
  for (const p of permits) {
    if (!inVisitDomain(p.stepIndex)) {
      violations.push(
        violation('permit-mismatch', p.screenId, p.stepIndex, {
          detail: 'beyond-route',
          permitKind: p.kind,
          seq: p.seq,
        }),
      );
    }
  }
  for (const rp of recordedPlans) {
    if (!inVisitDomain(rp.stepIndex)) {
      violations.push(
        violation('plan-divergence', null, rp.stepIndex, {
          detail: 'beyond-route',
          seq: rp.evaluationSeq,
        }),
      );
    }
  }
  for (const r of receipts) {
    if (!inVisitDomain(r.stepIndex)) {
      violations.push(
        violation('receipt-mismatch', r.screenId, r.stepIndex, { detail: 'beyond-route' }),
      );
    }
  }

  // ---- run shape (§3.5) ----------------------------------------------------
  const route = manifest.scenario;
  for (let i = 0; i < visits.length; i += 1) {
    const expected = route[i];
    if (!expected) {
      violations.push(
        violation('route-shape', visits[i].screenId, i, {
          detail: 'beyond-scenario',
          declaredCount: route.length,
          visitIndex: i,
        }),
      );
      continue;
    }
    if (visits[i].screenId !== expected.screen_ref) {
      violations.push(
        violation('route-shape', visits[i].screenId, i, {
          detail: 'screen-mismatch',
          expectedRef: expected.screen_ref,
          visitIndex: i,
        }),
      );
    }
    if (!manifestIds.has(visits[i].screenId)) {
      violations.push(
        violation('route-shape', visits[i].screenId, i, {
          detail: 'undeclared-screen',
          visitIndex: i,
        }),
      );
    }
  }
  if (fullJournalAudit && !sealedRun && visits.length !== route.length) {
    violations.push(
      violation('route-shape', null, null, {
        detail: 'count-mismatch',
        count: visits.length,
        declaredCount: route.length,
      }),
    );
  }
  const liveResourceIds = new Map<string, number>();
  visits.forEach((visit, i) => {
    const known = liveResourceIds.get(visit.screenId);
    if (known !== undefined && known !== visit.resourceId) {
      violations.push(
        violation('resource-id-inconsistent', visit.screenId, i, {
          resourceIdFrom: known,
          resourceIdTo: visit.resourceId,
        }),
      );
    }
    liveResourceIds.set(visit.screenId, visit.resourceId);
  });

  // ---- per-step audits ------------------------------------------------------
  for (let i = 0; i < visits.length; i += 1) {
    const visit = visits[i];
    const screen = screensById.get(visit.screenId);
    if (!screen) continue;
    // the framework's initial scope executes only correct routes; the schema keeps the slot (§3.8)
    const expectedCorrect = (route[i]?.expected_verdict ?? 'correct') === 'correct';
    const owned = ownedByVisit.get(i) ?? [];
    const evaluations = owned.filter((e) => e.record.resolution === 'evaluation');
    const stepPermits = permits.filter((p) => p.stepIndex === i);
    const windowEnd = i + 1 < visits.length ? visits[i + 1].entrySeq : Number.MAX_SAFE_INTEGER;

    // ---- permit inventory (§3.4): identity, fencing, role, duplicates -----
    for (const p of stepPermits) {
      if (p.screenId !== visit.screenId) {
        violations.push(
          violation('permit-mismatch', visit.screenId, i, {
            detail: 'screen-mismatch',
            permitKind: p.kind,
            seq: p.seq,
          }),
        );
      }
      // the lower fence binds EVERY step, the first included — pre-entry
      // NAVIGATION traffic is governed by its sequence rule, never by a
      // permit stamped before the identity fence existed
      if (p.seq <= visit.entrySeq || p.seq >= windowEnd) {
        violations.push(
          violation('permit-mismatch', visit.screenId, i, {
            detail: 'outside-window',
            permitKind: p.kind,
            seq: p.seq,
            entrySeq: visit.entrySeq,
          }),
        );
      }
      // role allowlist, BOTH directions (§3.4 + the navigation amendment):
      // navigation stamps widget-button only — the driver performs no check
      // click and no acknowledgment there; every other role stamps
      // check-click/feedback-ack only
      const allowed: readonly PermitKind[] =
        screen.role === 'navigation' ? ['widget-button'] : ['check-click', 'feedback-ack'];
      if (!allowed.includes(p.kind)) {
        violations.push(
          violation('permit-mismatch', visit.screenId, i, {
            detail: 'wrong-role',
            permitKind: p.kind,
            seq: p.seq,
          }),
        );
      }
    }
    (['check-click', 'feedback-ack', 'widget-button'] as const).forEach((kind) => {
      const ofKind = stepPermits.filter((p) => p.kind === kind);
      if (ofKind.length > 1) {
        violations.push(
          violation('permit-mismatch', visit.screenId, i, {
            detail: 'duplicate',
            permitKind: kind,
            count: ofKind.length,
          }),
        );
      }
    });

    // ---- recorded-plan inventory (§3.5): one-to-one with owned evaluations,
    // keyed by step AND evaluation — a duplicate, misattributed or unmatched
    // record can never stand in for the required evidence
    const ownedEvalSeqs = new Set(evaluations.map((e) => e.record.requestSeq));
    const seenPlanSeqs = new Set<number>();
    for (const p of recordedPlans.filter((rp) => rp.stepIndex === i)) {
      if (seenPlanSeqs.has(p.evaluationSeq)) {
        violations.push(
          violation('plan-divergence', visit.screenId, i, {
            detail: 'duplicate',
            seq: p.evaluationSeq,
          }),
        );
      }
      seenPlanSeqs.add(p.evaluationSeq);
      if (!ownedEvalSeqs.has(p.evaluationSeq)) {
        violations.push(
          violation('plan-divergence', visit.screenId, i, {
            detail: 'unused',
            seq: p.evaluationSeq,
          }),
        );
      }
    }

    // ---- receipt inventory (§3.5): exactly one per GRADED step, zero on
    // every other role — a duplicate or wrong-role receipt is positive
    // evidence, never silently ignored
    const stepReceipts = receipts.filter((r) => r.stepIndex === i);
    if (screen.role !== 'graded' && stepReceipts.length > 0) {
      violations.push(
        violation('receipt-mismatch', visit.screenId, i, {
          detail: 'wrong-role',
          count: stepReceipts.length,
        }),
      );
    }
    if (screen.role === 'graded' && stepReceipts.length > 1) {
      violations.push(
        violation('receipt-mismatch', visit.screenId, i, {
          detail: 'duplicate',
          count: stepReceipts.length,
        }),
      );
    }

    // unresolved candidates owned by any window are violations — fail-closed (§3.5)
    for (const e of owned) {
      if (e.record.resolution === 'unresolved') {
        violations.push(
          violation('unresolved-candidate-owned', visit.screenId, i, {
            seq: e.record.requestSeq,
            terminal: e.record.terminal,
          }),
        );
      }
    }

    // pre-entry traffic is legal only on a navigation first screen (§3.3)
    if (i === 0 && screen.role !== 'navigation') {
      for (const e of evaluations) {
        if (e.attributed.preEntry) {
          violations.push(
            violation('pre-entry-illegal', visit.screenId, i, { seq: e.record.requestSeq }),
          );
        }
      }
    }

    // every counted evaluation must be usable (§3.5)
    for (const e of evaluations) {
      if (!usable(e.record)) {
        violations.push(
          violation('evaluation-unusable', visit.screenId, i, {
            seq: e.record.requestSeq,
            status: e.record.status,
          }),
        );
      }
    }

    // payload provenance on owned evaluations (§3.3, evaluations ONLY)
    for (const e of evaluations) {
      const prefixes = extractSubmittedPrefixes(e.record.partInputs);
      const { violations: contamination } = resolveProvenance({
        submittedPrefixes: prefixes,
        owningScreenId: visit.screenId,
        declaredDependencies: screen.dependencies ?? [],
        ancestors: screen.layer_parents ?? [],
        manifestScreenIds: manifestIds,
      });
      for (const prefix of contamination) {
        violations.push(
          violation('provenance-contamination', visit.screenId, i, {
            seq: e.record.requestSeq,
            prefix,
          }),
        );
      }
    }

    if (screen.role === 'navigation') {
      // the screen definition names an in-widget action — a fully audited
      // window must hold the ONE widget-button permit proving the driver
      // performed it: an unsolicited deck transition is not the operation
      if (fullWindowAudit(i) && !stepPermits.some((p) => p.kind === 'widget-button')) {
        violations.push(
          violation('permit-mismatch', visit.screenId, i, {
            detail: 'missing',
            permitKind: 'widget-button',
          }),
        );
      }
      auditNavigationSequence(violations, visit, i, screen, evaluations, snapshot);
      // the widget's own check dance is not licensed click-by-click (§3.4),
      // but the run-shape/terminal obligations still bind its LAST plan —
      // and a recorded plan, when the driver produced one, must agree
      auditNavObligations(
        violations,
        visit,
        i,
        screen,
        evaluations,
        visits,
        snapshot,
        manifest,
        recordedPlans,
        fullWindowAudit(i),
      );
      continue;
    }

    // ---- non-navigation: causal edges + cardinality (§3.4) ----------------
    const ordered = [...evaluations].sort((a, b) => a.record.requestSeq - b.record.requestSeq);
    const checkClick = stepPermits.find((p) => p.kind === 'check-click');
    const feedbackAck = stepPermits.find((p) => p.kind === 'feedback-ack');
    const combineFeedback = !!screen.combine_feedback;

    const first = ordered[0];
    const firstUsable = first !== undefined && usable(first.record);
    const firstPlan: PlannedTransition | null = firstUsable
      ? planTransition(resultsOf(first.record), first.record.llmFeedback, combineFeedback)
      : null;

    // evaluation-capable permits must be consumed (§3.4, SF2): a check-click
    // with no evaluation, or a feedback-ack with no feedback plan to
    // acknowledge, is positive evidence of a driver/deck disagreement
    if (fullWindowAudit(i)) {
      if (checkClick && ordered.length === 0) {
        violations.push(
          violation('permit-mismatch', visit.screenId, i, {
            detail: 'unused',
            permitKind: 'check-click',
            seq: checkClick.seq,
          }),
        );
      }
      // an ack is licensed only AFTER a feedback plan (§3.4): no usable first
      // evaluation — zero evaluations included — leaves the permit unused too
      if (feedbackAck && (firstPlan === null || firstPlan.kind !== 'feedback')) {
        violations.push(
          violation('permit-mismatch', visit.screenId, i, {
            detail: 'unused',
            permitKind: 'feedback-ack',
            seq: feedbackAck.seq,
          }),
        );
      }
    }

    ordered.forEach((e, n) => {
      const edge =
        n === 0
          ? checkClick && checkClick.seq < e.record.requestSeq
            ? checkClick
            : undefined
          : n === 1
            ? screen.role === 'graded' &&
              feedbackAck &&
              feedbackAck.seq < e.record.requestSeq &&
              firstUsable &&
              feedbackAck.seq > (first.record.responseSeq as number) &&
              firstPlan?.kind === 'feedback' &&
              firstPlan.ack.kind === 'recheck'
              ? feedbackAck
              : undefined
            : undefined;
      if (!edge) {
        violations.push(
          violation('evaluation-no-causal-edge', visit.screenId, i, {
            count: n + 1,
            seq: e.record.requestSeq,
          }),
        );
      }
    });

    if (fullWindowAudit(i)) {
      // §3.5: a CONTENT step is exactly one evaluation, unconditionally — a
      // feedback-ack permit never raises its licence; only graded steps may
      // legally re-check
      const licensed =
        screen.role === 'graded' &&
        feedbackAck &&
        firstPlan?.kind === 'feedback' &&
        firstPlan.ack.kind === 'recheck'
          ? 2
          : 1;
      if (ordered.length !== licensed) {
        violations.push(
          violation('evaluation-count', visit.screenId, i, {
            count: ordered.length,
            expectedCount: licensed,
          }),
        );
      }
    }

    // first evaluation belongs to the RENDERED attempt (§3.5)
    if (first && first.record.attemptGuid !== visit.renderedAttemptGuid) {
      violations.push(
        violation('attempt-anchor', visit.screenId, i, {
          guid: first.record.attemptGuid,
          expectedGuid: visit.renderedAttemptGuid,
        }),
      );
    }

    // ---- graded/content specifics -----------------------------------------
    const receipt = receipts.find((r) => r.stepIndex === i) ?? null;
    if (screen.role === 'graded') {
      if (!receipt) {
        if (fullWindowAudit(i)) {
          violations.push(violation('receipt-missing', visit.screenId, i));
        }
      } else {
        auditReceiptIdentity(violations, visit, i, receipt, screen);
        auditGradedStep(
          violations,
          visit,
          i,
          receipt,
          ordered,
          snapshot,
          checkClick,
          fullWindowAudit(i),
        );
        if (receipt.matcher === 'cross_screen') {
          auditCrossScreenStep(violations, visit, i, receipt, screen, ordered, visits, snapshot);
        }
      }
      for (const e of ordered) {
        if (usable(e.record) && e.record.correct !== expectedCorrect) {
          violations.push(
            violation('verdict-not-correct', visit.screenId, i, {
              seq: e.record.requestSeq,
              verdict: e.record.correct,
              expectedVerdict: expectedCorrect,
            }),
          );
        }
      }
    }

    // ---- transition fidelity: recorded vs replay + fulfilled obligations ---
    auditTransitions(
      violations,
      visit,
      i,
      screen,
      ordered,
      visits,
      snapshot,
      manifest,
      stepPermits,
      combineFeedback,
      recordedPlans,
      fullWindowAudit(i),
    );
  }

  // ---- end-of-run invariants (skipped on any seal, §3.2 matrix) ------------
  if (!sealedRun) {
    if (snapshot.lessonEndSeq === null) {
      violations.push(violation('terminal-obligation', null, null, { detail: 'no-lesson-end' }));
    }
    if (snapshot.freezeFlavor === 'completed-failure') {
      violations.push(
        violation('terminal-obligation', null, null, {
          detail: 'finalization-misbehaved',
          reason: snapshot.finalizationFailure?.reason ?? 'unknown',
        }),
      );
    }
  }

  // §3.2: an ordinary bail can never audit clean — when a SEALED snapshot
  // carries no failure evidence at all, that absence is itself the finding
  // (the wrapper failed to stamp, or the seal hides the defect)
  if (sealedRun && violations.length === 0) {
    violations.push(violation('seal-without-evidence', null, null));
  }

  return violations;
}

/**
 * The receipt is driver evidence, not authority (§3.5): its identity,
 * matcher and expectations must correspond to the MANIFEST's screen
 * definition — a detached or drifted copy cannot substitute the contract.
 */
function auditReceiptIdentity(
  violations: Violation[],
  visit: RunVisit,
  stepIndex: number,
  receipt: StepReceipt,
  screen: ScreenDefinition,
): void {
  if (receipt.screenId !== visit.screenId) {
    violations.push(
      violation('receipt-mismatch', visit.screenId, stepIndex, {
        detail: 'screen',
        otherScreenId: receipt.screenId,
      }),
    );
  }
  const expectedMatcher = (screen.dependencies ?? []).length > 0 ? 'cross_screen' : 'local';
  if (receipt.matcher !== expectedMatcher) {
    violations.push(
      violation('receipt-mismatch', visit.screenId, stepIndex, { detail: 'matcher' }),
    );
  }
  const manifestExpectations = screen.expectations ?? [];
  if (JSON.stringify(receipt.expectations) !== JSON.stringify(manifestExpectations)) {
    violations.push(
      violation('receipt-mismatch', visit.screenId, stepIndex, { detail: 'expectations' }),
    );
  }
}

/**
 * Navigation sequence rule (§3.4) — ONE rule over the whole owned sequence,
 * pre-entry included. Legal shapes, exhaustively: empty; one usable
 * evaluation under a single attempt whose plan navigates or terminates; or
 * the measured rotation (incorrect non-navigating check → causal 2xx mint
 * between → correct navigating check under the minted guid).
 */
function auditNavigationSequence(
  violations: Violation[],
  visit: RunVisit,
  stepIndex: number,
  screen: ScreenDefinition,
  evaluations: OwnedEvaluation[],
  snapshot: JournalSnapshot,
): void {
  const ordered = [...evaluations].sort((a, b) => a.record.requestSeq - b.record.requestSeq);
  if (ordered.length === 0) return;
  const combineFeedback = !!screen.combine_feedback;

  for (const e of ordered) {
    if (!usable(e.record)) return; // already reported as evaluation-unusable
  }

  if (ordered.length === 1) {
    const only = ordered[0].record;
    const plan = planTransition(resultsOf(only), only.llmFeedback, combineFeedback);
    if (only.correct === false && !transitionNavigates(plan)) {
      violations.push(
        violation('navigation-sequence', visit.screenId, stepIndex, {
          detail: 'incorrect-singleton',
          seq: only.requestSeq,
        }),
      );
    } else if (!transitionNavigates(plan)) {
      violations.push(
        violation('navigation-sequence', visit.screenId, stepIndex, {
          detail: 'non-navigating-singleton',
          seq: only.requestSeq,
          planKind: plan.kind,
        }),
      );
    }
    return;
  }

  if (ordered.length === 2) {
    const [first, second] = ordered.map((e) => e.record);
    const firstPlan = planTransition(resultsOf(first), first.llmFeedback, combineFeedback);
    const secondPlan = planTransition(resultsOf(second), second.llmFeedback, combineFeedback);
    const mint = snapshot.records.find(
      (r) =>
        r.wireClass === 'creation' &&
        r.terminal === 'completed' &&
        r.attemptGuid === first.attemptGuid &&
        r.mintedGuid === second.attemptGuid &&
        r.status !== null &&
        r.status >= 200 &&
        r.status < 300 &&
        r.responseSeq !== null &&
        first.responseSeq !== null &&
        r.requestSeq > first.responseSeq &&
        second.requestSeq > r.responseSeq,
    );
    // the first half derives FEEDBACK or NONE — shadow-measured 2026-08-09:
    // the deck's incorrect nav check returns one result with an EMPTY actions
    // array (plan 'none'); the widget handles feedback internally. Navigating
    // first plans stay illegal. (§3.4 amendment pending B0.)
    const measuredRotation =
      first.attemptGuid !== second.attemptGuid &&
      first.correct === false &&
      (firstPlan.kind === 'feedback' || firstPlan.kind === 'none') &&
      !transitionNavigates(firstPlan) &&
      second.correct === true &&
      transitionNavigates(secondPlan) &&
      mint !== undefined;
    if (!measuredRotation) {
      violations.push(
        violation('navigation-sequence', visit.screenId, stepIndex, {
          detail: 'rotation-unproven',
          seq: first.requestSeq,
          seq2: second.requestSeq,
          mintObserved: mint !== undefined,
          planKind: firstPlan.kind,
          planKind2: secondPlan.kind,
        }),
      );
    }
    return;
  }

  violations.push(
    violation('navigation-sequence', visit.screenId, stepIndex, {
      detail: 'too-many',
      count: ordered.length,
    }),
  );
}

type SubmittedPair = { path: string; value: unknown };
type PartEntry = {
  partAttemptGuid: string | null;
  path: string;
  value: unknown;
  /** a path-only entry can never be committed state — consumers decide */
  hasValue: boolean;
};

function partEntries(partInputs: unknown[] | null): PartEntry[] {
  if (!partInputs) return [];
  const entries: PartEntry[] = [];
  for (const part of partInputs) {
    const p = part as {
      attemptGuid?: unknown;
      response?: Record<string, unknown> | null;
    } | null;
    const response = p?.response;
    if (!response || typeof response !== 'object') continue;
    const partAttemptGuid = typeof p?.attemptGuid === 'string' ? p.attemptGuid : null;
    const input =
      response.input && typeof response.input === 'object'
        ? (response.input as Record<string, unknown>)
        : response;
    for (const item of Object.values(input)) {
      const entry = item as { path?: unknown; value?: unknown } | null;
      if (entry && typeof entry.path === 'string')
        entries.push({
          partAttemptGuid,
          path: entry.path,
          value: entry.value,
          hasValue: 'value' in entry,
        });
    }
  }
  return entries;
}

function submittedPairs(partInputs: unknown[] | null): SubmittedPair[] {
  return partEntries(partInputs).map(({ path, value }) => ({ path, value }));
}

/** `<seq>|stage.<partId>.<key>` → `<partId>` — the server's partition key (§3.6). */
function partIdOf(path: string): string {
  const local = path.includes('|') ? path.slice(path.indexOf('|') + 1) : path;
  const m = /^stage\.([^.]+)\./.exec(local);
  return m ? m[1] : local;
}

/** Distinct satisfied PATHS — one duplicated blank can never satisfy min_count (R4-SF3). */
function expectationSatisfied(pairs: SubmittedPair[], e: GradingExpectation): boolean {
  if ('part_path' in e) {
    const atPath = pairs.filter((p) => p.path === e.part_path || p.path.endsWith(e.part_path));
    return atPath.some((p) => evaluatePredicate(e.predicate, p.value));
  }
  const underPrefix = pairs.filter((p) => p.path.includes(e.part_path_prefix));
  if (e.predicate === undefined) {
    // presence-only expectations still count DISTINCT paths (R4-SF3):
    // repeated entries for one path can never satisfy a declared min_count
    return new Set(underPrefix.map((p) => p.path)).size >= (e.min_count ?? 1);
  }
  const predicate = e.predicate;
  const satisfiedPaths = new Set(
    underPrefix.filter((p) => evaluatePredicate(predicate, p.value)).map((p) => p.path),
  );
  return satisfiedPaths.size >= (e.min_count ?? 1);
}

function auditGradedStep(
  violations: Violation[],
  visit: RunVisit,
  stepIndex: number,
  receipt: StepReceipt,
  ordered: OwnedEvaluation[],
  snapshot: JournalSnapshot,
  checkClick: Permit | undefined,
  fullAudit: boolean,
): void {
  // savedBarrier: a PATCH save observed AFTER readback completed and BEFORE
  // the check-click permit (§3.5) — a save emitted mid-gesture cannot satisfy
  // it. "No such save" is an ABSENCE conclusion: only a closed+settled window
  // may draw it (§3.2 matrix) — an open or unsettled window may still hold it.
  if (receipt.savedBarrierPrefixes && receipt.savedBarrierPrefixes.length > 0 && fullAudit) {
    const lower = receipt.readbackCompletedSeq;
    const upper = checkClick?.seq;
    for (const prefix of receipt.savedBarrierPrefixes) {
      // the save must have COMMITTED before the click — its response, not
      // merely its request, precedes the permit: an in-flight save at
      // click-time proves nothing about what the evaluation read
      const satisfied =
        lower !== undefined &&
        upper !== undefined &&
        snapshot.records.some(
          (r) =>
            r.wireClass === 'save' &&
            r.terminal === 'completed' &&
            r.status !== null &&
            r.status >= 200 &&
            r.status < 300 &&
            r.requestSeq > lower &&
            r.responseSeq !== null &&
            r.responseSeq < upper &&
            submittedPairs(r.partInputs).some((p) => p.path.includes(prefix)),
        );
      if (!satisfied) {
        violations.push(
          violation('saved-barrier', visit.screenId, stepIndex, {
            prefix,
            lowerSeq: lower ?? null,
            upperSeq: upper ?? null,
          }),
        );
      }
    }
  }

  for (const e of ordered) {
    if (!usable(e.record)) continue;
    if (receipt.matcher === 'local') {
      const pairs = submittedPairs(e.record.partInputs);
      const missing = receipt.expectations.filter((x) => !expectationSatisfied(pairs, x));
      for (const x of missing) {
        violations.push(
          violation('payload-mismatch', visit.screenId, stepIndex, {
            seq: e.record.requestSeq,
            pathLabel: 'part_path' in x ? x.part_path : `${x.part_path_prefix}*`,
          }),
        );
      }
    }
  }
}

/**
 * Attempt lineage as an ordered list (§3.3/§3.6): the rendered attempt,
 * extended causally by parsed 2xx mints in responseSeq order — the same
 * entered-at rooting the attribution module proves membership with.
 */
export function attemptLineage(
  records: readonly JournalRecord[],
  renderedGuid: string,
): { lineage: string[]; forked: boolean } {
  const mints = records
    .filter(
      (r) =>
        r.wireClass === 'creation' &&
        r.terminal === 'completed' &&
        r.mintedGuid !== null &&
        r.attemptGuid !== null &&
        r.status !== null &&
        r.status >= 200 &&
        r.status < 300 &&
        r.responseSeq !== null,
    )
    .sort((a, b) => (a.responseSeq as number) - (b.responseSeq as number));
  const entered = new Map<string, number>([[renderedGuid, 0]]);
  const lineage: string[] = [renderedGuid];
  const childCount = new Map<string, number>();
  for (const mint of mints) {
    const parentEnteredAt = entered.get(mint.attemptGuid as string);
    if (parentEnteredAt === undefined || parentEnteredAt >= mint.requestSeq) continue;
    if (!entered.has(mint.mintedGuid as string)) {
      entered.set(mint.mintedGuid as string, mint.responseSeq as number);
      lineage.push(mint.mintedGuid as string);
      childCount.set(
        mint.attemptGuid as string,
        (childCount.get(mint.attemptGuid as string) ?? 0) + 1,
      );
    }
  }
  // the server's "newest" is the greatest DATABASE id (`hierarchy.ex:603-627`)
  // — an ordering the wire cannot observe. A causal CHAIN (every parent has
  // exactly one rooted child) has one provable tip; sibling mints FORK the
  // order and must fail closed at the consumer.
  const forked = Array.from(childCount.values()).some((n) => n > 1);
  return { lineage, forked };
}

/**
 * Committed-prior-state matcher (§3.6): reproduces the server's selection —
 * newest activity attempt of the dependency's lineage, then within it the
 * newest PART attempt per part_id (`hierarchy.ex` `get_latest_attempts`).
 * The wire cannot prove part-attempt ROW order, so multiple observed part
 * attempts for one part_id fail closed as `ambiguousParts` instead of
 * guessing; the state must hold STABLE through the checking evaluation's
 * responseSeq (a deliberate strengthening — the server reads at an
 * unobservable instant mid-evaluation).
 */
export type CommittedPriorState = {
  state: Map<string, unknown>;
  /** part_ids whose part-attempt ordering the journal cannot prove — fail closed */
  ambiguousParts: string[];
};

export function committedPriorState(
  snapshot: JournalSnapshot,
  dependencyLineage: readonly string[],
  atSeq: number,
): CommittedPriorState {
  const minted = new Set<string>();
  for (const r of snapshot.records) {
    if (
      r.wireClass === 'creation' &&
      r.terminal === 'completed' &&
      r.mintedGuid !== null &&
      r.status !== null &&
      r.status >= 200 &&
      r.status < 300 &&
      r.responseSeq !== null &&
      r.responseSeq < atSeq
    ) {
      minted.add(r.mintedGuid);
    }
  }
  // newest = the LAST lineage member that exists before atSeq
  let newest: string | null = null;
  for (const guid of dependencyLineage) {
    if (guid === dependencyLineage[0] || minted.has(guid)) newest = guid;
  }
  const state = new Map<string, unknown>();
  if (newest === null) return { state, ambiguousParts: [] };
  // COMMITS, not merely saves (§3.6): a successful activity-attempt PUT also
  // persists its submitted part responses — the server's later
  // `get_latest_attempts` read sees both. Wire order proves commit order only
  // for NON-OVERLAPPING requests; two commits to one part whose
  // request→response windows overlap are an ambiguity, handled below.
  const commits = snapshot.records
    .filter(
      (r) =>
        (r.wireClass === 'save' ||
          (r.wireClass === 'eval-candidate' && r.resolution !== 'unresolved')) &&
        r.terminal === 'completed' &&
        r.attemptGuid === newest &&
        r.status !== null &&
        r.status >= 200 &&
        r.status < 300 &&
        r.responseSeq !== null &&
        r.responseSeq < atSeq,
    )
    .sort((a, b) => (a.responseSeq as number) - (b.responseSeq as number));
  // per part_id: the server selects the newest part-attempt ROW
  // (`hierarchy.ex` `get_latest_attempts`, ordered by database id) — an
  // ordering the wire does NOT expose. One observed part attempt per part is
  // unambiguous: each save REPLACES its response wholesale (the server
  // stores the submitted map, never merging paths across saves). TWO OR MORE
  // part-attempt guids for one part_id are an AMBIGUITY the journal cannot
  // resolve — response observation order is not creation-row order — so the
  // matcher fails closed and reports the part instead of guessing.
  const perPart = new Map<string, { guid: string | null; paths: Map<string, unknown> }>();
  const ambiguous = new Set<string>();
  const windowsByPart = new Map<string, Array<{ from: number; to: number }>>();
  for (const commit of commits) {
    const inThisCommit = new Map<string, { guid: string | null; paths: Map<string, unknown> }>();
    for (const entry of partEntries(commit.partInputs)) {
      if (!entry.hasValue) continue; // malformed for committed state (§3.6)
      const partId = partIdOf(entry.path);
      const bucket = inThisCommit.get(partId) ?? { guid: entry.partAttemptGuid, paths: new Map() };
      if (bucket.guid !== entry.partAttemptGuid) ambiguous.add(partId);
      bucket.paths.set(entry.path, entry.value);
      inThisCommit.set(partId, bucket);
    }
    inThisCommit.forEach((bucket, partId) => {
      const known = perPart.get(partId);
      if (known && known.guid !== bucket.guid) ambiguous.add(partId);
      // response order proves commit order only when the requests do NOT
      // overlap: two in-flight commits to one part are server-order opaque
      const window = { from: commit.requestSeq, to: commit.responseSeq as number };
      const windows = windowsByPart.get(partId) ?? [];
      if (windows.some((w) => w.from < window.to && window.from < w.to)) {
        ambiguous.add(partId);
      }
      windows.push(window);
      windowsByPart.set(partId, windows);
      perPart.set(partId, bucket); // this commit's map replaces the response
    });
  }
  perPart.forEach(({ paths }, partId) => {
    if (ambiguous.has(partId)) return;
    paths.forEach((value, path) => state.set(path, value));
  });
  return { state, ambiguousParts: Array.from(ambiguous).sort() };
}

/**
 * Cross-screen receipt audit (§3.6): per declared dependency, the committed
 * prior state must hold stable through the checking evaluation's response
 * and, combined across dependencies, satisfy every expectation.
 */
export function auditCrossScreenReceipt(
  snapshot: JournalSnapshot,
  receipt: StepReceipt,
  dependencyLineages: ReadonlyArray<readonly string[]>,
  checking: JournalRecord,
): Violation[] {
  const violations: Violation[] = [];
  if (checking.responseSeq === null) {
    return [
      violation('payload-mismatch', receipt.screenId, receipt.stepIndex, {
        detail: 'no-response',
        seq: checking.requestSeq,
      }),
    ];
  }
  const combined: SubmittedPair[] = [];
  for (const lineage of dependencyLineages) {
    const atRequest = committedPriorState(snapshot, lineage, checking.requestSeq);
    const throughResponse = committedPriorState(snapshot, lineage, checking.responseSeq + 1);
    const ambiguousParts = Array.from(
      new Set([...atRequest.ambiguousParts, ...throughResponse.ambiguousParts]),
    ).sort();
    if (ambiguousParts.length > 0) {
      // the journal cannot prove which part attempt the server selected —
      // fail closed, name the parts, never guess (§3.6)
      for (const partId of ambiguousParts) {
        violations.push(
          violation('payload-mismatch', receipt.screenId, receipt.stepIndex, {
            detail: 'ambiguous-part-order',
            pathLabel: partId,
          }),
        );
      }
      return violations;
    }
    const stable =
      atRequest.state.size === throughResponse.state.size &&
      Array.from(atRequest.state.entries()).every(
        ([path, value]) =>
          throughResponse.state.has(path) &&
          JSON.stringify(throughResponse.state.get(path)) === JSON.stringify(value),
      );
    if (!stable) {
      violations.push(
        violation('payload-mismatch', receipt.screenId, receipt.stepIndex, {
          detail: 'unstable-dependency',
          seq: checking.requestSeq,
        }),
      );
      return violations;
    }
    atRequest.state.forEach((value, path) => combined.push({ path, value }));
  }
  for (const x of receipt.expectations.filter((e) => !expectationSatisfied(combined, e))) {
    violations.push(
      violation('payload-mismatch', receipt.screenId, receipt.stepIndex, {
        pathLabel: 'part_path' in x ? x.part_path : `${x.part_path_prefix}*`,
      }),
    );
  }
  return violations;
}

/**
 * The cross-screen path THROUGH the public contract (§3.5/§3.6): dependency
 * lineages are derived from audited evidence — each dependency's own visit
 * stamp roots its lineage; the checking evaluation is the step's first
 * usable one. A dependency with no earlier visit cannot be matched at all.
 */
function auditCrossScreenStep(
  violations: Violation[],
  visit: RunVisit,
  stepIndex: number,
  receipt: StepReceipt,
  screen: ScreenDefinition,
  ordered: OwnedEvaluation[],
  visits: RunVisit[],
  snapshot: JournalSnapshot,
): void {
  const checking = ordered.find((e) => usable(e.record))?.record;
  if (!checking) return; // usability/cardinality violations already cover this window
  const lineages: string[][] = [];
  for (const dep of screen.dependencies ?? []) {
    const depVisit = visits.slice(0, stepIndex).find((v) => v.screenId === dep);
    if (!depVisit) {
      violations.push(
        violation('receipt-mismatch', visit.screenId, stepIndex, {
          detail: 'dependency-unvisited',
          dependencyId: dep,
        }),
      );
      return;
    }
    const { lineage, forked } = attemptLineage(snapshot.records, depVisit.renderedAttemptGuid);
    if (forked) {
      // sibling mints: the wire cannot prove which row the server calls
      // newest (`hierarchy.ex` orders by database id) — fail closed, like
      // the part-attempt ambiguity
      violations.push(
        violation('payload-mismatch', visit.screenId, stepIndex, {
          detail: 'ambiguous-attempt-order',
          dependencyId: dep,
        }),
      );
      return;
    }
    lineages.push(lineage);
  }
  violations.push(...auditCrossScreenReceipt(snapshot, receipt, lineages, checking));
}

/**
 * Navigation screens skip permit licensing (§3.4) but not run-shape/terminal
 * fidelity: the LAST usable plan's terminal/navigate obligation still binds.
 * Absence-based conclusions (missing successor, missing lesson end) apply
 * only under a full window audit (§3.2 failure-state matrix). Obligations
 * are causally bounded by the RESPONSE that created the plan — evidence
 * predating it proves nothing.
 */
function auditNavObligations(
  violations: Violation[],
  visit: RunVisit,
  stepIndex: number,
  screen: ScreenDefinition,
  evaluations: OwnedEvaluation[],
  visits: RunVisit[],
  snapshot: JournalSnapshot,
  manifest: AdaptiveManifest,
  recordedPlans: RecordedPlan[],
  fullAudit: boolean,
): void {
  const usableOrdered = evaluations
    .filter((e) => usable(e.record))
    .sort((a, b) => a.record.requestSeq - b.record.requestSeq);
  const last = usableOrdered[usableOrdered.length - 1];
  if (!last) return;
  const plan = planTransition(
    resultsOf(last.record),
    last.record.llmFeedback,
    !!screen.combine_feedback,
  );
  // §3.5 replay agreement binds EVERY owned evaluation — navigation included:
  // clicks are not licensed here (§3.4), but the driver observes every
  // response and must record its online plan. The rotation's own obligations
  // (first plan non-navigating, causal mint, ack-licensed second check) are
  // the sequence rule's shape — the widget's internal ack has no wire trace,
  // so mint + second evaluation IS the observable fulfillment.
  for (const e of usableOrdered) {
    const replayed = planTransition(
      resultsOf(e.record),
      e.record.llmFeedback,
      !!screen.combine_feedback,
    );
    // `none` on a NAVIGATION evaluation is measured-legal (the rotation's
    // first check, empty actions result — shadow capture 2026-08-09); the
    // sequence rule bounds what such a plan may be part of. §3.5's
    // none-is-illegal rule applies to non-navigation roles, in
    // auditTransitions. (§3.5 amendment pending B0.)
    const recorded = recordedPlans.find(
      (p) => p.stepIndex === stepIndex && p.evaluationSeq === e.record.requestSeq,
    );
    if (recorded === undefined) {
      if (fullAudit) {
        violations.push(
          violation('plan-divergence', visit.screenId, stepIndex, {
            detail: 'missing-recorded-plan',
            seq: e.record.requestSeq,
          }),
        );
      }
      continue;
    }
    if (!samePlan(recorded.plan, replayed)) {
      violations.push(
        violation('plan-divergence', visit.screenId, stepIndex, {
          seq: e.record.requestSeq,
          planKind: recorded.plan.kind,
          planKind2: replayed.kind,
        }),
      );
    }
  }
  const responseSeq = last.record.responseSeq as number;
  const isLastStep = stepIndex === manifest.scenario.length - 1;

  if (plan.kind === 'terminal') {
    if (!isLastStep) {
      violations.push(
        violation('obligation-unfulfilled', visit.screenId, stepIndex, {
          planKind: 'terminal',
          detail: 'no-lesson-end',
        }),
      );
    } else if (
      fullAudit &&
      (snapshot.lessonEndSeq === null || snapshot.lessonEndSeq < responseSeq)
    ) {
      violations.push(
        violation('obligation-unfulfilled', visit.screenId, stepIndex, {
          planKind: 'terminal',
          detail: 'no-lesson-end',
          seq: last.record.requestSeq,
        }),
      );
    }
    return;
  }
  if (!transitionNavigates(plan)) return; // the sequence rule already judged it
  const target =
    plan.kind === 'auto-navigate'
      ? plan.target
      : plan.kind === 'feedback' && plan.ack.kind === 'navigate'
        ? plan.ack.target
        : '';
  if (isLastStep) {
    if (target !== 'next') {
      violations.push(
        violation('obligation-unfulfilled', visit.screenId, stepIndex, {
          detail: 'target-not-next',
          target,
        }),
      );
    } else if (
      fullAudit &&
      (snapshot.lessonEndSeq === null || snapshot.lessonEndSeq < responseSeq)
    ) {
      violations.push(
        violation('obligation-unfulfilled', visit.screenId, stepIndex, {
          detail: 'no-lesson-completion',
        }),
      );
    }
  } else {
    // the plan's NORMALIZED target must resolve to the scenario's declared
    // successor — `next` is proven offline (ArchiveFacts route edges); an
    // explicit target must name it (positive evidence, ungated)
    const successorRef = manifest.scenario[stepIndex + 1]?.screen_ref;
    if (target !== 'next' && target !== successorRef) {
      violations.push(
        violation('obligation-unfulfilled', visit.screenId, stepIndex, {
          detail: 'wrong-successor-target',
          target,
          expectedRef: successorRef,
        }),
      );
    }
    if (fullAudit) {
      const successor = visits[stepIndex + 1];
      if (!successor || successor.entrySeq < responseSeq) {
        violations.push(
          violation('obligation-unfulfilled', visit.screenId, stepIndex, {
            detail: 'no-successor',
            seq: last.record.requestSeq,
          }),
        );
      }
    }
  }
}

function auditTransitions(
  violations: Violation[],
  visit: RunVisit,
  stepIndex: number,
  screen: ScreenDefinition,
  ordered: OwnedEvaluation[],
  visits: RunVisit[],
  snapshot: JournalSnapshot,
  manifest: AdaptiveManifest,
  stepPermits: Permit[],
  combineFeedback: boolean,
  recordedPlans: RecordedPlan[],
  fullAudit: boolean,
): void {
  const isLastStep = stepIndex === manifest.scenario.length - 1;
  const usableOrdered = ordered.filter((e) => usable(e.record));

  usableOrdered.forEach((e, n) => {
    const plan = planTransition(resultsOf(e.record), e.record.llmFeedback, combineFeedback);
    const responseSeq = e.record.responseSeq as number;
    const isFinalEvaluation = n === usableOrdered.length - 1;

    // §3.5 replay agreement: the driver's RECORDED online plan must exist
    // and match the replay. A divergence is positive evidence; a missing
    // record is an absence conclusion, gated like every other one.
    const recorded = recordedPlans.find(
      (p) => p.stepIndex === stepIndex && p.evaluationSeq === e.record.requestSeq,
    );
    if (recorded === undefined) {
      if (fullAudit) {
        violations.push(
          violation('plan-divergence', visit.screenId, stepIndex, {
            detail: 'missing-recorded-plan',
            seq: e.record.requestSeq,
          }),
        );
      }
    } else if (!samePlan(recorded.plan, plan)) {
      violations.push(
        violation('plan-divergence', visit.screenId, stepIndex, {
          seq: e.record.requestSeq,
          planKind: recorded.plan.kind,
          planKind2: plan.kind,
        }),
      );
    }

    if (plan.kind === 'none') {
      violations.push(
        violation('plan-illegal', visit.screenId, stepIndex, {
          seq: e.record.requestSeq,
          planKind: 'none',
        }),
      );
      return;
    }
    if (n > 0 && !transitionNavigates(plan) && plan.kind !== 'terminal') {
      violations.push(
        violation('plan-illegal', visit.screenId, stepIndex, {
          seq: e.record.requestSeq,
          planKind: plan.kind,
        }),
      );
    }

    // every plan's obligation must be FULFILLED by later evidence (§3.5);
    // "later" is causally bounded by the plan's own RESPONSE — an ack or a
    // successor stamped before the response existed proves nothing; absence
    // conclusions only under a full window audit (§3.2 matrix)
    if (plan.kind === 'feedback') {
      const ack = stepPermits.find((p) => p.kind === 'feedback-ack' && p.seq > responseSeq);
      if (!ack) {
        if (fullAudit) {
          violations.push(
            violation('obligation-unfulfilled', visit.screenId, stepIndex, {
              detail: 'no-ack',
              seq: e.record.requestSeq,
            }),
          );
        }
        return;
      }
      if (plan.ack.kind === 'recheck') {
        const second = usableOrdered[n + 1];
        if (fullAudit && (!second || second.record.requestSeq < ack.seq)) {
          violations.push(
            violation('obligation-unfulfilled', visit.screenId, stepIndex, {
              detail: 'no-second-evaluation',
              seq: e.record.requestSeq,
            }),
          );
        }
        return;
      }
    }

    if (isFinalEvaluation && transitionNavigates(plan)) {
      const target =
        plan.kind === 'auto-navigate'
          ? plan.target
          : plan.kind === 'feedback' && plan.ack.kind === 'navigate'
            ? plan.ack.target
            : 'endOfLesson';
      if (plan.kind === 'terminal') {
        if (fullAudit && (snapshot.lessonEndSeq === null || snapshot.lessonEndSeq < responseSeq)) {
          violations.push(
            violation('obligation-unfulfilled', visit.screenId, stepIndex, {
              planKind: 'terminal',
              detail: 'no-lesson-end',
              seq: e.record.requestSeq,
            }),
          );
        }
      } else if (isLastStep) {
        // navigate OFF SEQUENCE: fulfilled by lesson completion, and only for
        // the normalized target `next` on the archive-proven last step (§3.5)
        if (target !== 'next') {
          violations.push(
            violation('obligation-unfulfilled', visit.screenId, stepIndex, {
              detail: 'target-not-next',
              target,
            }),
          );
        } else if (
          fullAudit &&
          (snapshot.lessonEndSeq === null || snapshot.lessonEndSeq < responseSeq)
        ) {
          violations.push(
            violation('obligation-unfulfilled', visit.screenId, stepIndex, {
              detail: 'no-lesson-completion',
            }),
          );
        }
      } else {
        const successorRef = manifest.scenario[stepIndex + 1]?.screen_ref;
        if (target !== 'next' && target !== successorRef) {
          violations.push(
            violation('obligation-unfulfilled', visit.screenId, stepIndex, {
              detail: 'wrong-successor-target',
              target,
              expectedRef: successorRef,
            }),
          );
        }
        if (fullAudit) {
          const successor = visits[stepIndex + 1];
          if (!successor || successor.entrySeq < responseSeq) {
            violations.push(
              violation('obligation-unfulfilled', visit.screenId, stepIndex, {
                detail: 'no-successor',
                seq: e.record.requestSeq,
              }),
            );
          }
        }
      }
    }

    if (plan.kind === 'terminal' && !isLastStep) {
      violations.push(
        violation('obligation-unfulfilled', visit.screenId, stepIndex, {
          planKind: 'terminal',
          detail: 'no-lesson-end',
        }),
      );
    }
  });
}

/**
 * §3.7 reporter — the ONLY render path. Templates are exhaustive over the
 * code union (the Record enforces it); they interpolate exclusively the
 * closed fact fields: identities, seqs, counts, kinds, plans — never values.
 */
const TEMPLATES: Record<ViolationCode, (f: ViolationFacts) => string> = {
  'route-shape': (f) =>
    f.detail === 'beyond-scenario'
      ? `visit ${String(f.visitIndex)} is beyond the scenario's ${String(f.declaredCount)} steps`
      : f.detail === 'screen-mismatch'
        ? `visit ${String(f.visitIndex)} does not show the declared screen "${String(f.expectedRef)}"`
        : f.detail === 'undeclared-screen'
          ? `visited screen has no screen definition`
          : `visited ${String(f.count)} screens, the scenario declares ${String(f.declaredCount)}`,
  'resource-id-inconsistent': (f) =>
    `screen changed live resourceId ${String(f.resourceIdFrom)} -> ${String(f.resourceIdTo)}`,
  'evaluation-unusable': (f) =>
    `evaluation (seq ${String(f.seq)}) unusable: status ${String(f.status)}`,
  'evaluation-no-causal-edge': (f) =>
    `evaluation ${String(f.count)} (seq ${String(f.seq)}) has no licensing permit`,
  'evaluation-count': (f) =>
    `saw ${String(f.count)} evaluation(s), licensed exactly ${String(f.expectedCount)}`,
  'navigation-sequence': (f) =>
    f.detail === 'incorrect-singleton'
      ? `incorrect non-navigating singleton (seq ${String(f.seq)}) — the first half of a rotation whose completion was never proven`
      : f.detail === 'non-navigating-singleton'
        ? `navigation singleton (seq ${String(f.seq)}) derives plan "${String(f.planKind)}", which neither navigates nor terminates`
        : f.detail === 'rotation-unproven'
          ? `two evaluations (seqs ${String(f.seq)}, ${String(f.seq2)}) are licensed only as the measured rotation; mint ${f.mintObserved ? 'observed' : 'missing'}, plans [${String(f.planKind)}, ${String(f.planKind2)}]`
          : `${String(f.count)} evaluations owned by a navigation screen — the sequence rule licenses at most the measured rotation`,
  'verdict-not-correct': (f) =>
    `evaluation (seq ${String(f.seq)}) verdict=${String(f.verdict)}, the scenario expects ${String(f.expectedVerdict)}`,
  'receipt-missing': () => 'graded screen has no answer receipt',
  'receipt-mismatch': (f) =>
    f.detail === 'screen'
      ? `receipt names screen "${String(f.otherScreenId)}"`
      : f.detail === 'matcher'
        ? 'receipt matcher does not correspond to the manifest dependencies'
        : f.detail === 'dependency-unvisited'
          ? `declared dependency "${String(f.dependencyId)}" has no earlier visit`
          : f.detail === 'beyond-route'
            ? 'receipt names a step with no visit'
            : f.detail === 'wrong-role'
              ? `${String(f.count)} receipt(s) on a non-graded step`
              : f.detail === 'duplicate'
                ? `${String(f.count)} receipts for one graded step — exactly one is licensed`
                : 'receipt expectations do not correspond to the manifest',
  'payload-mismatch': (f) =>
    f.detail === 'no-response'
      ? `cross-screen check (seq ${String(f.seq)}) has no response to hold the prior state stable through`
      : f.detail === 'unstable-dependency'
        ? 'dependency state mutated inside the check request→response window — the stale-correct receipt cannot pass'
        : f.detail === 'ambiguous-part-order'
          ? `part "${String(f.pathLabel)}" shows multiple part attempts — the journal cannot prove which row the server selected`
          : f.detail === 'ambiguous-attempt-order'
            ? `dependency "${String(f.dependencyId)}" shows sibling attempt mints — the journal cannot prove which row the server selected`
            : `payload does not satisfy expectation at ${String(f.pathLabel)}${f.seq !== undefined ? ` (seq ${String(f.seq)})` : ''}`,
  'attempt-anchor': (f) =>
    `first evaluation used attempt ${String(f.guid)}, the screen rendered ${String(f.expectedGuid)}`,
  'saved-barrier': (f) =>
    `no committed PATCH save carrying "${String(f.prefix)}" between readback (seq ${String(f.lowerSeq)}) and check-click (seq ${String(f.upperSeq)})`,
  'plan-illegal': (f) =>
    f.planKind === 'none'
      ? `evaluation (seq ${String(f.seq)}) derives plan "none" — not a legal post-check plan`
      : `re-check (seq ${String(f.seq)}) must end in navigation or terminal, derived "${String(f.planKind)}"`,
  'plan-divergence': (f) =>
    f.detail === 'missing-recorded-plan'
      ? `evaluation (seq ${String(f.seq)}) has no recorded online plan to compare with the replay`
      : f.detail === 'duplicate'
        ? `duplicate recorded plan for evaluation seq ${String(f.seq)}`
        : f.detail === 'unused'
          ? `recorded plan (evaluation seq ${String(f.seq)}) matches no owned evaluation of its step`
          : f.detail === 'beyond-route'
            ? `recorded plan (evaluation seq ${String(f.seq)}) names a step with no visit`
            : `evaluation (seq ${String(f.seq)}) recorded plan "${String(f.planKind)}" but the replay derives "${String(f.planKind2)}"`,
  'permit-mismatch': (f) =>
    f.detail === 'screen-mismatch'
      ? `${String(f.permitKind)} permit (seq ${String(f.seq)}) names another screen`
      : f.detail === 'outside-window'
        ? `${String(f.permitKind)} permit (seq ${String(f.seq)}) is outside its visit window (entry seq ${String(f.entrySeq)})`
        : f.detail === 'duplicate'
          ? `${String(f.count)} ${String(f.permitKind)} permits in one step — at most one is licensed`
          : f.detail === 'wrong-role'
            ? `${String(f.permitKind)} permit (seq ${String(f.seq)}) is not licensed for its screen's role`
            : f.detail === 'beyond-route'
              ? `${String(f.permitKind)} permit (seq ${String(f.seq)}) names a step with no visit`
              : f.detail === 'missing'
                ? `fully audited navigation window holds no ${String(f.permitKind)} permit`
                : `${String(f.permitKind)} permit (seq ${String(f.seq)}) licensed nothing that happened`,
  'obligation-unfulfilled': (f) =>
    f.detail === 'no-ack'
      ? `feedback plan (seq ${String(f.seq)}) has no acknowledging permit after its response`
      : f.detail === 'no-second-evaluation'
        ? `expect-recheck plan (seq ${String(f.seq)}) has no ack-licensed second evaluation`
        : f.detail === 'target-not-next'
          ? `final-step navigation to "${String(f.target)}" cannot be fulfilled by lesson end — only "next" qualifies`
          : f.detail === 'no-lesson-completion'
            ? 'final-step navigate-off-sequence without lesson completion'
            : f.detail === 'wrong-successor-target'
              ? `navigate plan targets "${String(f.target)}", the scenario's successor is "${String(f.expectedRef)}"`
              : f.detail === 'no-successor'
                ? `navigate plan (seq ${String(f.seq)}) has no following visit stamp after its response`
                : f.planKind === 'terminal' && f.seq !== undefined
                  ? `terminal plan (seq ${String(f.seq)}) without the deck lesson-end signal`
                  : 'terminal plan before the last scenario step',
  'unresolved-candidate-owned': (f) =>
    `unresolved evaluation candidate (seq ${String(f.seq)}, terminal ${String(f.terminal)})`,
  'provenance-contamination': (f) =>
    `evaluation (seq ${String(f.seq)}) submitted prefix "${String(f.prefix)}" — not own, declared dependency, or whitelisted ancestor`,
  lineage: (f) =>
    `evaluation under attempt ${String(f.guid)} (seq ${String(f.seq)}) is outside the screen's attempt lineage`,
  'pre-entry-illegal': (f) =>
    `pre-entry evaluation (seq ${String(f.seq)}) on a non-navigation first screen`,
  'terminal-obligation': (f) =>
    f.detail === 'finalization-misbehaved'
      ? `page-lifecycle finalization misbehaved: ${String(f.reason)}`
      : 'frozen run without the deck lesson-end signal',
  'freeze-timeout': (f) =>
    `accepted finalization but traffic never quiesced (outstanding at expiry: ${String(f.outstanding)})`,
  'seal-without-evidence': () =>
    'sealed run carries no failure evidence — an ordinary bail cannot audit clean (§3.2)',
  'request-failed': (f) =>
    `request (seq ${String(f.seq)}) ended ${String(f.terminal)} (status ${String(f.status)}) — failed traffic is reported, never silent`,
  'operation-failure': (f) =>
    f.detail === 'beyond-route'
      ? 'operation failure names a step with no scenario position'
      : f.detail === 'screen-mismatch'
        ? `operation failure attribution contradicts its kind (names "${String(f.otherScreenId)}")`
        : `driver operation failed: ${String(f.failureKind)}`,
};

/** §3.7 reporter: identities, counts, kinds, plans — never values. */
export function formatViolations(violations: Violation[]): string {
  if (violations.length === 0) return 'auditRun: no violations';
  const lines = violations.map(
    (v, i) =>
      `${String(i).padStart(2)} [${v.code}] ${v.screenId ?? '(run)'}${v.stepIndex !== null ? `@${v.stepIndex}` : ''}: ${TEMPLATES[v.code](v.facts)}`,
  );
  return `auditRun: ${violations.length} violation(s)\n${lines.join('\n')}`;
}
