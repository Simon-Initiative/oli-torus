import * as fs from 'fs';
import * as path from 'path';

import ts from 'typescript';

import { expect, test } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import {
  AdaptiveJournalCore,
  FinalizationFailureReason,
  JournalRecord,
} from '@tasks/AdaptiveJournal';
import { AdaptiveManifest } from '@tasks/AdaptiveManifest';
import { OperationFailure, RunRecord, auditRun } from '@tasks/AdaptiveOracle';

import {
  Clock,
  MANIFEST,
  SCREENS,
  ScriptedDeck,
  ScriptedScreen,
  driveScripted,
  event,
  feedback,
  freeze,
  navTo,
} from './adaptiveStrictDeck';

/**
 * Exit-site inventory and per-site fault injection (gate-B rows B4-EXIT-INV,
 * B4-EXIT-EM, B4-EXIT-MAP; witnesses W-E1–W-E6).
 *
 * The artifact `gate-evidence/mer-5865-exit-inv.json` claims every control-flow
 * exit of the strict driver pins exactly ONE typed producer. These tests make
 * that claim falsifiable: the inventory is re-derived from the source on every
 * run, and each site is driven to its exit and asked what it actually emitted.
 *
 * SITE IDENTITY IS THE CALL EDGE (caller file:line -> callee + kind, qualified
 * by producing origin). The amendment to contract §1 step 1 is PROPOSED and
 * PENDING; `call-edge identity is what makes a shared callee single-valued`
 * below is the witness that the distinction is real.
 *
 * Rebuilt after Codex round 9 (5 blockers, all accepted).
 */

const AUTOMATION = path.resolve(__dirname, '../../..');
const DRIVER_REL = 'src/systems/torus/tasks/AdaptiveStrictDriver.ts';
const DRIVER_SRC = fs.readFileSync(path.join(AUTOMATION, DRIVER_REL), 'utf8').split('\n');

type Site = {
  id: string;
  caller: string;
  source_line: string;
  callee: string;
  origin: string;
  kind: string;
  class: string;
  producer: string;
  injection: { status: string; witness?: string; by?: string; reason?: string };
};

const ARTIFACT = JSON.parse(
  fs.readFileSync(path.join(AUTOMATION, 'gate-evidence/mer-5865-exit-inv.json'), 'utf8'),
) as {
  site_identity: { form: string; amendment_status: string; row_key: string };
  sites: Site[];
  interior_collapse: { per_method: Array<{ method: string; ruling: string }> };
  scope: { declared: string[]; exclusions: Array<Record<string, string>> };
  reviewer_comparison: { findings: Array<{ id: string; disposition: string }> };
};

/**
 * The membership rule the artifact is closed against, restated so the inventory
 * is re-derived rather than trusted. ROUND-9 BLOCKER 2: the round-8 pattern
 * could not see `new X`, `now()` or option reads, so the "independent" check was
 * blind to exactly the sites that were missing.
 */
const EDGE =
  /(\b(?:deck|entry|resolved|journal|recorder|options)\.[a-zA-Z])|(\b(?:resolveFamily|resolveOperations|planTransition|structuredClone|submittedPaths|recordPlan|recordObservedPlans|awaitQuiescence|awaitEvaluation|awaitSavedBarrier|awaitTransition|runStep|runGates|answerScreen|followPlan|perform|sleep|now)\s*\()|(\bnew [A-Z])|(\b(?:fail|stop)\s*\()|(throw new Error)|(\.records\(\))|(page\s*$)|(\.evaluate\()/;

const DECLARATION =
  /^\s*(const|let) (fail|stop|perform|awaitQuiescence|awaitEvaluation|awaitSavedBarrier|awaitTransition|recordPlan|recordObservedPlans|runGates|answerScreen|followPlan|runStep|sleep|now|log|timeouts) =/;

function candidateLines(): number[] {
  const hits: number[] = [];
  DRIVER_SRC.forEach((text, i) => {
    const t = text.trim();
    if (t.startsWith('*') || t.startsWith('//') || t.startsWith('/*')) return;
    if (!EDGE.test(text)) return;
    if (DECLARATION.test(text)) return;
    if (/^(export )?(async )?function /.test(text)) return;
    hits.push(i + 1);
  });
  return hits;
}

const lineOf = (site: Site): number => Number(site.caller.split(':')[1]);

// ---------------------------------------------------------------------------
// injection seams — a fault raised at ONE call edge, the deck otherwise intact
// ---------------------------------------------------------------------------

type Injection = {
  method: string;
  /** raise only while the deck shows this screen */
  onScreen?: string;
  /** raise on the Nth qualifying call (1-based); disambiguates repeat callees */
  onCall?: number;
  /** thrown value; a non-Error is itself a witness */
  value?: unknown;
  /** replace the method's result instead of throwing */
  returns?: unknown;
};

const wrapDeck =
  (inj: Injection) =>
  (deck: ScriptedDeck): object => {
    let calls = 0;
    return new Proxy(deck as unknown as Record<string | symbol, unknown>, {
      get(target, prop, receiver) {
        const orig = Reflect.get(target, prop, receiver);
        if (prop !== inj.method || typeof orig !== 'function') return orig;
        return (...args: unknown[]) => {
          const onScreen =
            inj.onScreen === undefined ||
            (target as unknown as ScriptedDeck).currentId === inj.onScreen;
          if (onScreen) {
            calls += 1;
            if (calls >= (inj.onCall ?? 1)) {
              if ('returns' in inj) return inj.returns;
              throw 'value' in inj ? inj.value : new Error(`injected fault at ${inj.method}`);
            }
          }
          return (orig as (...a: unknown[]) => unknown).apply(target, args);
        };
      },
    });
  };

const faultCore =
  (inj: Injection) =>
  (deck: ScriptedDeck, core: AdaptiveJournalCore): void => {
    const bag = core as unknown as Record<string, (...a: unknown[]) => unknown>;
    const orig = bag[inj.method].bind(core);
    let calls = 0;
    bag[inj.method] = (...args: unknown[]) => {
      const onScreen = inj.onScreen === undefined || deck.currentId === inj.onScreen;
      if (onScreen) {
        calls += 1;
        if (calls >= (inj.onCall ?? 1)) {
          if ('returns' in inj) return inj.returns;
          throw 'value' in inj ? inj.value : new Error(`injected fault at ${inj.method}`);
        }
      }
      return orig(...args);
    };
  };

/** A caller-supplied function that raises on its Nth call. */
const raisesOnCall = (n: number) => {
  let calls = 0;
  return (..._a: unknown[]): never | undefined => {
    calls += 1;
    if (calls >= n) throw new Error('injected fault in a caller-supplied function');
    return undefined;
  };
};

/** A throwing accessor on the caller's options object — the :684-:686 edges. */
const hostileOptions = (field: 'timeouts' | 'sleep' | 'now') => ({
  get [field]() {
    throw new Error(`injected fault reading options.${field}`);
  },
});

type Case = {
  witness: string;
  /** the artifact site this activates, as `file:line` */
  site: string;
  /** the artifact row's callee, so a case cannot claim a neighbouring edge */
  callee: string;
  at: 'deck' | 'core' | 'shape';
  inj?: Injection;
  /** custom core/deck preparation when faultCore's fixed shapes cannot reach the edge */
  prep?: (deck: ScriptedDeck, core: AdaptiveJournalCore, clock: Clock) => void;
  screens?: () => ScriptedScreen[];
  manifest?: () => AdaptiveManifest;
  options?: Record<string, unknown>;
  /** exactly this, and nothing else, in the run record */
  failures: OperationFailure[];
  /** stop sites emit NO failure; their producer is journal-side */
  journalCode?: string;
};

const OF = (
  kind: OperationFailure['kind'],
  screenId: string | null,
  step: number,
): OperationFailure => ({ kind, screenId, expectedStepIndex: step });

const IU0 = [OF('identity-unresolved', null, 0)];

const clone = (): AdaptiveManifest => JSON.parse(JSON.stringify(MANIFEST)) as AdaptiveManifest;

const gatedManifest = (gate: string): AdaptiveManifest => {
  const m = clone();
  (m.screens[1].operations ?? []).unshift({ id: 'op.gate', kind: 'gate', gate } as never);
  return m;
};

/** q:2's save lands mid-gesture, so the barrier loop never satisfies (:359 false). */
const midGestureSave = () => {
  const s = SCREENS();
  s[2].deferredSave = { paths: s[2].deferredSave!.paths, delayMs: 0 };
  return s;
};

/**
 * A clock-edge fault gated on the BARRIER screen being current, delegating to
 * the real scripted clock otherwise so deck timers keep firing. `nth` counts
 * only calls made while q:2 is current: for `now`, call 1 is the step-2 settle
 * deadline (:281) and call 2 is the barrier deadline (:346); the mid-gesture
 * screens push the loop so call 3 is the deadline recheck (:362). For `sleep`,
 * call 1 is the step-2 settle (:285) and call 2 the barrier poll (:370).
 */
function barrierClockCase(
  witness: string,
  site: string,
  which: 'now' | 'sleep',
  nth: number,
  screens: (() => ScriptedScreen[]) | undefined,
): Case[] {
  const ref: { deck: ScriptedDeck | null; clock: Clock | null; calls: number } = {
    deck: null,
    clock: null,
    calls: 0,
  };
  const impl =
    which === 'now'
      ? () => {
          if (ref.deck?.currentId === 'q:2') {
            ref.calls += 1;
            if (ref.calls >= nth) throw new Error(`injected fault at ${which} on q:2`);
          }
          return (ref.clock as Clock).now();
        }
      : async (ms: number) => {
          if (ref.deck?.currentId === 'q:2') {
            ref.calls += 1;
            if (ref.calls >= nth) throw new Error(`injected fault at ${which} on q:2`);
          }
          await (ref.clock as Clock).sleep(ms);
        };
  return [
    {
      witness,
      site: `${DRIVER_REL}${site}`,
      callee: which,
      at: 'shape',
      screens,
      prep: (deck, _core, clock) => {
        ref.deck = deck;
        ref.clock = clock;
      },
      options: { [which]: impl },
      failures: [OF('driver-internal', 'q:2', 2)],
    },
  ];
}

const CASES: Case[] = [
  // --- boundary-region initialisation (round-9 blocker 2) -------------------
  {
    witness: 'W-E2-OPTIONS',
    site: `${DRIVER_REL}:684`,
    callee: 'options.timeouts read + spread',
    at: 'shape',
    options: hostileOptions('timeouts'),
    failures: IU0,
  },
  {
    witness: 'W-E2-OPTIONS-SLEEP',
    site: `${DRIVER_REL}:685`,
    callee: 'options.sleep read',
    at: 'shape',
    options: hostileOptions('sleep'),
    failures: IU0,
  },
  {
    witness: 'W-E2-OPTIONS-NOW',
    site: `${DRIVER_REL}:686`,
    callee: 'options.now read',
    at: 'shape',
    options: hostileOptions('now'),
    failures: IU0,
  },
  {
    witness: 'W-E2-PRETRY',
    site: `${DRIVER_REL}:687`,
    callee: 'manifest.screens.map',
    at: 'shape',
    manifest: () => ({ scenario: MANIFEST.scenario }) as unknown as AdaptiveManifest,
    failures: IU0,
  },

  // --- awaitQuiescence -----------------------------------------------------
  {
    witness: 'W-E2-NOW-QUIESCENCE',
    site: `${DRIVER_REL}:281`,
    callee: 'now',
    at: 'shape',
    // `now` is caller-supplied; the first call is the quiescence deadline
    options: { now: raisesOnCall(1) },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-QUIESCENCE-READ',
    site: `${DRIVER_REL}:283`,
    callee: 'journal.outstanding',
    at: 'core',
    inj: { method: 'outstanding', onScreen: 'q:1' },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-WIRE-COUNT',
    site: `${DRIVER_REL}:284`,
    callee: 'journal.wireEventCount',
    at: 'core',
    inj: { method: 'wireEventCount', onScreen: 'q:1' },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-SLEEP-QUIESCENT',
    site: `${DRIVER_REL}:285`,
    callee: 'sleep',
    at: 'shape',
    // outstanding is 0, so the first driver sleep is the quiescent settle
    options: { sleep: raisesOnCall(1) },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-SLEEP-POLL',
    site: `${DRIVER_REL}:288`,
    callee: 'sleep',
    at: 'core',
    // traffic outstanding takes the BUSY branch, a different sleep edge
    inj: { method: 'outstanding', onScreen: 'q:1', returns: 1 },
    options: { sleep: raisesOnCall(1) },
    failures: [OF('driver-internal', 'n:1', 0)],
  },

  // --- awaitEvaluation -----------------------------------------------------
  {
    witness: 'W-E2-RECORDS-EVAL',
    site: `${DRIVER_REL}:309`,
    callee: 'journal.records',
    at: 'core',
    inj: { method: 'records', onScreen: 'q:1', onCall: 2 },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  {
    witness: 'W-E2-STOP-UNUSABLE',
    site: `${DRIVER_REL}:322`,
    callee: 'stop',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[1].checks = [
        { correct: true, results: [event(true, [navTo('next')])], deck: 'stay', broken: 'status' },
      ];
      return s;
    },
    failures: [],
    journalCode: 'unresolved-candidate-owned',
  },
  {
    witness: 'W-E2-EVAL-TIMEOUT',
    site: `${DRIVER_REL}:329`,
    callee: 'fail',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[1].checks = [];
      return s;
    },
    failures: [OF('check-click-no-effect', 'q:1', 1)],
  },
  {
    witness: 'W-E2-EVAL-TIMEOUT-ACK',
    site: `${DRIVER_REL}:329`,
    callee: 'fail',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      // the ack lands, but the re-check it licenses never reaches the wire:
      // the timeout arm must carry the ACK kind, not the check kind
      s[1].checks = [{ correct: true, results: [event(true, [feedback()])], deck: 'feedback' }];
      s[1].afterAck = 'stay';
      return s;
    },
    failures: [OF('ack-no-effect', 'q:1', 1)],
  },

  // --- awaitSavedBarrier ---------------------------------------------------
  {
    witness: 'W-E2-RECORDS-BARRIER',
    site: `${DRIVER_REL}:349`,
    callee: 'journal.records',
    at: 'core',
    inj: { method: 'records', onScreen: 'q:2' },
    failures: [OF('driver-internal', 'q:2', 2)],
  },
  {
    witness: 'W-E2-BARRIER-TIMEOUT',
    site: `${DRIVER_REL}:363`,
    callee: 'fail',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[2].deferredSave = { paths: s[2].deferredSave!.paths, delayMs: 0 };
      return s;
    },
    failures: [OF('barrier-timeout', 'q:2', 2)],
  },

  // --- plan recording ------------------------------------------------------
  {
    witness: 'W-E2-RECORDS-SWEEP',
    site: `${DRIVER_REL}:393`,
    callee: 'journal.records',
    at: 'core',
    // the navigation step sweeps AFTER its transition, so the deck already
    // shows q:1 while the driver is still inside step 0
    inj: { method: 'records', onScreen: 'q:1' },
    failures: [OF('driver-internal', 'n:1', 0)],
  },

  // --- runGates ------------------------------------------------------------
  {
    witness: 'W-E2-MEDIA',
    site: `${DRIVER_REL}:409`,
    callee: 'deck.playVideos',
    at: 'deck',
    inj: { method: 'playVideos', onScreen: 'c:1' },
    failures: [OF('readiness-timeout', 'c:1', 3)],
  },
  {
    witness: 'W-E2-MEDIA-CAROUSEL',
    site: `${DRIVER_REL}:410`,
    callee: 'deck.clickThroughCarousels',
    at: 'deck',
    // ROUND-9 BLOCKER 4: W-E2-MEDIA throws at :409, so :406/:410 is NEVER
    // reached by it. This edge needs its own injection.
    inj: { method: 'clickThroughCarousels', onScreen: 'c:1' },
    failures: [OF('readiness-timeout', 'c:1', 3)],
  },
  {
    witness: 'W-E2-GATE-VIDEO',
    site: `${DRIVER_REL}:417`,
    callee: 'deck.playVideos',
    at: 'shape',
    manifest: () => gatedManifest('video_start'),
    failures: [OF('gate-unsatisfied', 'q:1', 1)],
  },
  {
    witness: 'W-E2-GATE-CAROUSEL',
    site: `${DRIVER_REL}:421`,
    callee: 'deck.clickThroughCarousels',
    at: 'shape',
    manifest: () => gatedManifest('carousel_view'),
    failures: [OF('gate-unsatisfied', 'q:1', 1)],
  },
  {
    witness: 'W-E2-GATE-UNKNOWN',
    site: `${DRIVER_REL}:424`,
    callee: 'unknown gate',
    at: 'shape',
    manifest: () => gatedManifest('no_such_gate'),
    failures: [OF('gate-unsatisfied', 'q:1', 1)],
  },

  // --- answerScreen --------------------------------------------------------
  {
    witness: 'W-E2-PART-INVENTORY',
    site: `${DRIVER_REL}:439`,
    callee: 'deck.readPartInventory',
    at: 'deck',
    inj: { method: 'readPartInventory', onScreen: 'q:1' },
    failures: [OF('answer-failed', 'q:1', 1)],
  },
  {
    witness: 'W-E2-UNKNOWN-FAMILY',
    site: `${DRIVER_REL}:447`,
    callee: 'resolveFamily',
    at: 'shape',
    manifest: () => {
      const m = clone();
      (m.screens[1].operations ?? []).forEach((op) => {
        if (op.kind === 'answer') op.family = 'janus-nope';
      });
      return m;
    },
    failures: [OF('answer-failed', 'q:1', 1)],
  },
  {
    witness: 'W-E2-BAD-DIRECTIVE',
    site: `${DRIVER_REL}:452`,
    callee: 'resolved.validateDirective',
    at: 'shape',
    // ROUND-9 BLOCKER 4: the unknown-family test exits at resolveFamily and
    // never reaches validateDirective. A VALID family with an invalid
    // directive is what activates this edge.
    manifest: () => {
      const m = clone();
      (m.screens[1].operations ?? []).forEach((op) => {
        if (op.kind === 'answer') op.directive = { part_id: 'Choice' };
      });
      return m;
    },
    failures: [OF('answer-failed', 'q:1', 1)],
  },
  {
    witness: 'W-E2-DETECT',
    site: `${DRIVER_REL}:456`,
    callee: 'entry.detect',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      // a part of the WRONG type: ownJanusPart raises inside detect
      s[1].parts = [{ id: 'Choice', type: 'janus-input-text', src: null }];
      return s;
    },
    failures: [OF('answer-failed', 'q:1', 1)],
  },
  {
    witness: 'W-E2-UNOWNED-PART',
    site: `${DRIVER_REL}:457`,
    callee: 'no owned part',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      // right type, wrong id: detect returns nothing and the guard raises
      s[1].parts = [{ id: 'SomethingElse', type: 'janus-mcq', src: null }];
      return s;
    },
    failures: [OF('answer-failed', 'q:1', 1)],
  },
  {
    witness: 'W-E2-INTERIOR-REGISTRY',
    site: `${DRIVER_REL}:461`,
    callee: 'entry.ready',
    at: 'deck',
    // the SECOND waitForDeckReady on q:1 is the one the mcq registry entry
    // makes from inside ready() (AdaptiveFamilyRegistry.ts:197)
    inj: { method: 'waitForDeckReady', onScreen: 'q:1', onCall: 2 },
    failures: [OF('readiness-timeout', 'q:1', 1)],
  },
  {
    witness: 'W-E2-FIXTURE-INTERIOR',
    site: `${DRIVER_REL}:464`,
    callee: 'entry.answer',
    at: 'deck',
    // ROUND-9 BLOCKER 4: this drives the FIXTURE's primitive, not
    // AdaptiveDeckPO's. Named for what it proves. The production PO's own
    // absorbing catches are witnessed separately, against a real page.
    inj: { method: 'selectMcqByText', onScreen: 'q:1' },
    failures: [OF('answer-failed', 'q:1', 1)],
  },
  {
    witness: 'W-E2-READBACK',
    site: `${DRIVER_REL}:467`,
    callee: 'entry.readback',
    at: 'deck',
    inj: { method: 'mcqSelectionCount', onScreen: 'q:1' },
    failures: [OF('readback-failed', 'q:1', 1)],
  },
  {
    witness: 'W-E2-READBACK-FENCE',
    site: `${DRIVER_REL}:475`,
    callee: 'journal.issueReadbackFence',
    at: 'core',
    inj: { method: 'issueReadbackFence', onScreen: 'q:1' },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  {
    witness: 'W-E2-CLONE',
    site: `${DRIVER_REL}:487`,
    callee: 'structuredClone',
    at: 'shape',
    manifest: () => {
      const m = clone();
      (m.screens[1] as { expectations?: unknown }).expectations = [() => 1];
      return m;
    },
    failures: [OF('driver-internal', 'q:1', 1)],
  },

  // --- awaitTransition -----------------------------------------------------
  {
    witness: 'W-E2-LESSON-END-WAIT',
    site: `${DRIVER_REL}:501`,
    callee: 'deck.waitForLessonEnd',
    at: 'deck',
    inj: { method: 'waitForLessonEnd', onScreen: 'c:1' },
    failures: [OF('navigation-timeout', 'c:1', 3)],
  },
  {
    witness: 'W-E2-GRADED-NAV',
    site: `${DRIVER_REL}:506`,
    callee: 'deck.waitForScreenChange',
    at: 'deck',
    inj: { method: 'waitForScreenChange', onScreen: 'q:2' },
    failures: [OF('navigation-timeout', 'q:2', 2)],
  },

  // --- followPlan ----------------------------------------------------------
  {
    witness: 'W-E2-STOP-NONE-PLAN',
    site: `${DRIVER_REL}:528`,
    callee: 'stop',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[1].checks = [{ correct: true, results: [event(true, [])], deck: 'stay' }];
      return s;
    },
    failures: [],
    journalCode: 'any',
  },
  {
    witness: 'W-E2-FEEDBACK-OPEN',
    site: `${DRIVER_REL}:533`,
    callee: 'deck.waitForFeedbackOpen',
    at: 'deck',
    inj: { method: 'waitForFeedbackOpen', onScreen: 'q:1' },
    failures: [OF('feedback-never-opened', 'q:1', 1)],
  },
  {
    witness: 'W-E2-PERMIT-ACK',
    site: `${DRIVER_REL}:535`,
    callee: 'journal.issuePermit',
    at: 'core',
    inj: { method: 'issuePermit', onScreen: 'q:1', onCall: 2 },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  {
    witness: 'W-E2-ACK',
    site: `${DRIVER_REL}:538`,
    callee: 'deck.acknowledgeFeedback',
    at: 'deck',
    inj: { method: 'acknowledgeFeedback', onScreen: 'q:1' },
    failures: [OF('ack-no-effect', 'q:1', 1)],
  },
  {
    witness: 'W-E2-STOP-NONGRADED',
    site: `${DRIVER_REL}:556`,
    callee: 'stop',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[3].checks = [
        { correct: true, results: [event(true, [feedback()])], deck: 'feedback' },
        { correct: true, results: [event(true, [navTo('endOfLesson')])], deck: 'stay' },
      ];
      s[3].afterAck = 'recheck';
      return s;
    },
    failures: [],
    journalCode: 'evaluation-no-causal-edge',
  },
  {
    witness: 'W-E2-STOP-RECHECK-KIND',
    site: `${DRIVER_REL}:563`,
    callee: 'stop',
    at: 'shape',
    // ROUND-9 BLOCKER 4: the round-8 citation pointed at a sibling arm that
    // never reaches this guard. A GRADED re-check that plans feedback again
    // is what reaches it.
    screens: () => {
      const s = SCREENS();
      s[1].checks = [
        { correct: true, results: [event(true, [feedback()])], deck: 'feedback' },
        { correct: true, results: [event(true, [feedback()])], deck: 'stay' },
      ];
      s[1].afterAck = 'recheck';
      return s;
    },
    failures: [],
    journalCode: 'any',
  },

  // --- runStep -------------------------------------------------------------
  {
    witness: 'W-E2-UNDECLARED-SCREEN',
    site: `${DRIVER_REL}:578`,
    callee: 'undeclared screen',
    at: 'shape',
    manifest: () => {
      const m = clone();
      m.scenario[1].screen_ref = 'q:absent';
      return m;
    },
    failures: [OF('identity-unresolved', null, 1)],
  },
  {
    witness: 'W-E2-IDENTITY-READY',
    site: `${DRIVER_REL}:579`,
    callee: 'deck.waitForDeckReady',
    at: 'deck',
    inj: { method: 'waitForDeckReady', onScreen: 'n:1' },
    failures: IU0,
  },
  {
    witness: 'W-E2-IDENTITY-ENDED',
    site: `${DRIVER_REL}:580`,
    callee: 'deck.lessonEnded',
    at: 'deck',
    inj: { method: 'lessonEnded', onScreen: 'n:1' },
    failures: IU0,
  },
  {
    witness: 'W-E2-IDENTITY-READ',
    site: `${DRIVER_REL}:581`,
    callee: 'deck.readScreenIdentity',
    at: 'deck',
    inj: { method: 'readScreenIdentity', onScreen: 'n:1' },
    failures: IU0,
  },
  {
    witness: 'W-E2-IDENTITY-MISMATCH',
    site: `${DRIVER_REL}:583`,
    callee: 'identity mismatch',
    at: 'deck',
    inj: {
      method: 'readScreenIdentity',
      onScreen: 'q:1',
      returns: { id: 'x:9', resourceId: 9, attemptGuid: 'a-x9' },
    },
    failures: [OF('identity-unresolved', null, 1)],
  },
  {
    witness: 'W-E2-FENCE',
    site: `${DRIVER_REL}:589`,
    callee: 'journal.issueFence',
    at: 'core',
    inj: { method: 'issueFence', onScreen: 'n:1' },
    failures: IU0,
  },
  {
    witness: 'W-E2-OPERATIONS',
    site: `${DRIVER_REL}:600`,
    callee: 'resolveOperations',
    at: 'shape',
    manifest: () => {
      const m = clone();
      (m.scenario[1] as { operation_refs?: unknown }).operation_refs = 5;
      return m;
    },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  {
    witness: 'W-E2-NO-ACTION',
    site: `${DRIVER_REL}:614`,
    callee: 'no declared action',
    at: 'shape',
    manifest: () => {
      const m = clone();
      delete (m.screens[0] as { action?: unknown }).action;
      return m;
    },
    failures: [OF('widget-button-unavailable', 'n:1', 0)],
  },
  {
    witness: 'W-E2-WIDGET-READY',
    site: `${DRIVER_REL}:615`,
    callee: 'deck.widgetButtonReady',
    at: 'deck',
    inj: { method: 'widgetButtonReady', onScreen: 'n:1' },
    failures: [OF('widget-button-unavailable', 'n:1', 0)],
  },
  {
    witness: 'W-E2-WIDGET-UNRENDERED',
    site: `${DRIVER_REL}:616`,
    callee: 'button never rendered',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[0].widget = undefined;
      return s;
    },
    failures: [OF('widget-button-unavailable', 'n:1', 0)],
  },
  {
    witness: 'W-E2-PERMIT-WIDGET',
    site: `${DRIVER_REL}:620`,
    callee: 'journal.issuePermit',
    at: 'core',
    inj: { method: 'issuePermit', onScreen: 'n:1' },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-WIDGET-CLICK',
    site: `${DRIVER_REL}:628`,
    callee: 'deck.clickWidgetButton',
    at: 'deck',
    inj: { method: 'clickWidgetButton', onScreen: 'n:1' },
    failures: [OF('widget-button-unavailable', 'n:1', 0)],
  },
  {
    witness: 'W-E2-WIDGET-UNCLICKABLE',
    site: `${DRIVER_REL}:629`,
    callee: 'button not clickable',
    at: 'deck',
    inj: { method: 'clickWidgetButton', onScreen: 'n:1', returns: false },
    failures: [OF('widget-button-unavailable', 'n:1', 0)],
  },
  {
    witness: 'W-E2-WIDGET-NAV',
    site: `${DRIVER_REL}:634`,
    callee: 'deck.waitForScreenChange',
    at: 'deck',
    inj: { method: 'waitForScreenChange', onScreen: 'n:1' },
    failures: [OF('navigation-timeout', 'n:1', 0)],
  },
  {
    witness: 'W-E2-TRAFFIC-NAV',
    site: `${DRIVER_REL}:637`,
    callee: 'fail',
    at: 'core',
    inj: { method: 'outstanding', onScreen: 'q:1', returns: 1 },
    failures: [OF('traffic-unsettled', 'n:1', 0)],
  },
  {
    witness: 'W-E2-CHECK-READY',
    site: `${DRIVER_REL}:654`,
    callee: 'deck.waitForCheckEnabled',
    at: 'deck',
    inj: { method: 'waitForCheckEnabled', onScreen: 'q:1' },
    failures: [OF('readiness-timeout', 'q:1', 1)],
  },
  {
    witness: 'W-E2-PERMIT-CHECK',
    site: `${DRIVER_REL}:656`,
    callee: 'journal.issuePermit',
    at: 'core',
    inj: { method: 'issuePermit', onScreen: 'q:1' },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  {
    witness: 'W-E2-CHECK-CLICK',
    site: `${DRIVER_REL}:659`,
    callee: 'deck.submitCheck',
    at: 'deck',
    inj: { method: 'submitCheck', onScreen: 'q:1' },
    failures: [OF('check-click-no-effect', 'q:1', 1)],
  },
  {
    witness: 'W-E2-TRAFFIC-GRADED',
    site: `${DRIVER_REL}:672`,
    callee: 'fail',
    at: 'core',
    inj: { method: 'outstanding', onScreen: 'q:2', returns: 1 },
    failures: [OF('traffic-unsettled', 'q:1', 1)],
  },

  // --- outer boundary ------------------------------------------------------
  {
    witness: 'W-E2-LESSON-END-READ',
    site: `${DRIVER_REL}:695`,
    callee: 'deck.lessonEnded',
    at: 'deck',
    inj: { method: 'lessonEnded', onScreen: 'c:1', onCall: 2 },
    failures: [OF('driver-internal', 'c:1', 3)],
  },
  {
    witness: 'W-E2-NOTE-LESSON-END',
    site: `${DRIVER_REL}:695`,
    callee: 'journal.noteLessonEnd',
    at: 'core',
    inj: { method: 'noteLessonEnd' },
    failures: [OF('driver-internal', 'c:1', 3)],
  },
  // --- round-10 blocker 3: the 13 formerly waived edges, injected AT-SITE ----
  {
    witness: 'W-E2-QUIESCENCE-RECHECK',
    site: `${DRIVER_REL}:286`,
    callee: 'journal.outstanding',
    at: 'core',
    // the SECOND outstanding read of the pass — the settle recheck, not :283.
    // step-0's quiescence runs with the NEXT screen already current
    inj: { method: 'outstanding', onScreen: 'q:1', onCall: 2 },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-WIRE-RECOUNT',
    site: `${DRIVER_REL}:286`,
    callee: 'journal.wireEventCount',
    at: 'core',
    inj: { method: 'wireEventCount', onScreen: 'q:1', onCall: 2 },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-NOW-QUIESCENCE-DEADLINE',
    site: `${DRIVER_REL}:290`,
    callee: 'now',
    at: 'core',
    // busy branch so the loop reaches the deadline check: outstanding lies once
    inj: { method: 'outstanding', onScreen: 'q:1', returns: 1 },
    options: { now: raisesOnCall(2) },
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-NOW-EVAL',
    site: `${DRIVER_REL}:306`,
    callee: 'now',
    at: 'shape',
    // call 1 is the n:1 quiescence deadline; call 2 opens awaitEvaluation
    options: { now: raisesOnCall(2) },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  {
    witness: 'W-E2-NOW-EVAL-DEADLINE',
    site: `${DRIVER_REL}:328`,
    callee: 'now',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[1].checks = [];
      return s;
    },
    options: { now: raisesOnCall(3) },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  {
    witness: 'W-E2-SLEEP-EVAL-POLL',
    site: `${DRIVER_REL}:336`,
    callee: 'sleep',
    at: 'shape',
    screens: () => {
      const s = SCREENS();
      s[1].checks = [];
      return s;
    },
    options: { sleep: raisesOnCall(2) },
    failures: [OF('driver-internal', 'q:1', 1)],
  },
  ...barrierClockCase('W-E2-NOW-BARRIER', ':346', 'now', 2, undefined),
  {
    witness: 'W-E2-SUBMITTED-PATHS',
    site: `${DRIVER_REL}:359`,
    callee: 'submittedPaths',
    at: 'core',
    // a record whose partInputs ACCESS throws — the fault raises during the
    // argument evaluation of submittedPaths(r.partInputs) on this line
    inj: {
      method: 'records',
      onScreen: 'q:2',
      returns: [
        {
          wireClass: 'save',
          terminal: 'completed',
          status: 200,
          responseSeq: 1,
          requestSeq: 99_999,
          get partInputs(): never {
            throw new Error('injected fault at partInputs access');
          },
        },
      ],
    },
    failures: [OF('driver-internal', 'q:2', 2)],
  },
  ...barrierClockCase('W-E2-NOW-BARRIER-DEADLINE', ':362', 'now', 3, midGestureSave),
  ...barrierClockCase('W-E2-SLEEP-BARRIER-POLL', ':370', 'sleep', 2, midGestureSave),
  {
    witness: 'W-E2-PLAN-ARG',
    site: `${DRIVER_REL}:379`,
    callee: 'planTransition',
    at: 'shape',
    // the record passes `usable` untouched; its llmFeedback ACCESS throws, so
    // the fault raises during planTransition's argument evaluation on :379
    prep: (deck, core) => {
      const bag = core as unknown as { records(): JournalRecord[] };
      const orig = bag.records.bind(core);
      bag.records = () =>
        orig().map((r) =>
          deck.currentId === 'q:1' && r.wireClass === 'eval-candidate'
            ? new Proxy(r, {
                get(t, prop, recv) {
                  if (prop === 'llmFeedback') throw new Error('injected fault at llmFeedback');
                  return Reflect.get(t, prop, recv);
                },
              })
            : r,
        );
    },
    // the step-0 SWEEP records the nav evaluation's plan first, so the
    // poisoned llmFeedback access raises at :379 during step 0
    failures: [OF('driver-internal', 'n:1', 0)],
  },
  {
    witness: 'W-E2-SAVED-BARRIER-PART',
    site: `${DRIVER_REL}:469`,
    callee: 'entry.savedBarrier',
    at: 'shape',
    // the part's id ACCESS throws only on the read AFTER readback's — the one
    // capiClusterPrefix performs inside entry.savedBarrier on this line
    prep: (deck) => {
      const d = deck as unknown as { readPartInventory(): Promise<unknown[]> };
      const orig = d.readPartInventory.bind(deck);
      d.readPartInventory = async () => {
        const parts = (await orig()) as Array<{ type: string; id: string }>;
        if (deck.currentId !== 'q:2') return parts;
        let idReads = 0;
        return parts.map((p) =>
          p.type === 'janus-capi-iframe'
            ? new Proxy(p, {
                get(t, prop, recv) {
                  if (prop === 'id') {
                    idReads += 1;
                    if (idReads >= 2) throw new Error('injected fault at part.id access');
                  }
                  return Reflect.get(t, prop, recv);
                },
              })
            : p,
        );
      };
    },
    failures: [OF('driver-internal', 'q:2', 2)],
  },
  {
    witness: 'W-E2-MAP-ITERATOR',
    site: `${DRIVER_REL}:687`,
    callee: 'new Map',
    at: 'shape',
    // screens.map returns an iterable whose element is NOT an entry object, so
    // the Map CONSTRUCTOR itself throws — refuting the round-9 waiver
    manifest: () =>
      ({
        scenario: MANIFEST.scenario,
        screens: {
          map: () => ({
            *[Symbol.iterator]() {
              yield 42;
            },
          }),
        },
      }) as unknown as AdaptiveManifest,
    failures: IU0,
  },
];

// ---------------------------------------------------------------------------

test.describe('exit-site inventory — B4-EXIT-INV (W-E1)', () => {
  test('every inventoried site still cites the source line it claims', () => {
    const wrong: string[] = [];
    ARTIFACT.sites.forEach((site) => {
      const text = (DRIVER_SRC[lineOf(site) - 1] ?? '').trim();
      if (text !== site.source_line) {
        wrong.push(
          `${site.id} ${site.caller}\n  artifact: ${site.source_line}\n  source:   ${text}`,
        );
      }
    });
    expect(wrong, `the inventory has drifted from the driver:\n${wrong.join('\n')}`).toEqual([]);
  });

  test('the site set equals the candidate set derived from the source (both directions)', () => {
    const claimed: Record<number, boolean> = {};
    ARTIFACT.sites.forEach((s) => {
      claimed[lineOf(s)] = true;
    });
    const nonSites = [109, 112, 187];
    const machinery = [252, 263, 276, 697];
    const prospective = [105, 106, 113, 127, 136, 138, 140, 144, 148, 154];
    // the log body reads options inside its own swallowing try (scope.exclusions)
    const swallowed = [212];
    const accounted = ([] as number[]).concat(nonSites, machinery, prospective, swallowed);
    const unclaimed = candidateLines().filter((l) => !claimed[l] && accounted.indexOf(l) < 0);
    expect(
      unclaimed,
      `source lines exit the module but no inventory row claims them: ${unclaimed.join(', ')}`,
    ).toEqual([]);

    const phantom = ARTIFACT.sites.filter((s) => !DRIVER_SRC[lineOf(s) - 1]);
    expect(phantom.map((s) => s.caller)).toEqual([]);
  });

  test('every site pins exactly one producer — no unions, no placeholders', () => {
    // ROUND-9 BLOCKER 3: the round-8 version of this test only rejected an
    // empty string, so `JR | OF(ack-no-effect)` passed an assertion whose name
    // promised single-valued producers.
    const bad = ARTIFACT.sites.filter(
      (s) =>
        !s.producer ||
        s.producer.indexOf('|') >= 0 ||
        s.producer.indexOf('<') >= 0 ||
        s.producer.indexOf('every') >= 0 ||
        s.producer === '∅' ||
        s.producer === 'none-guaranteed',
    );
    expect(
      bad.map((s) => `${s.id} ${s.caller} -> ${s.producer}`),
      'a row that names more than one producer cannot satisfy "each site pins exactly ONE typed producer"',
    ).toEqual([]);
  });

  test('nothing above the outer boundary can execute caller code or a constructor', () => {
    // ROUND-9 BLOCKER 2, checked STRUCTURALLY rather than by pattern: parse the
    // region between the signature and `try {` and require every statement to
    // initialise from a constant, a literal, or an unexecuted lambda.
    const start = DRIVER_SRC.findIndex((l) => l.indexOf('): Promise<StrictRunOutcome> {') >= 0);
    const end = DRIVER_SRC.findIndex((l, i) => i > start && /^ {2}try \{/.test(l));
    expect(start, 'the driver entry point moved').toBeGreaterThan(0);
    expect(end, 'the outer boundary moved').toBeGreaterThan(start);

    const offenders: string[] = [];
    for (let i = start + 1; i < end; i += 1) {
      const text = DRIVER_SRC[i];
      if (!/^ {2}(const|let) /.test(text)) continue;
      const eq = text.indexOf(' = ');
      if (eq < 0) continue; // a declaration with no initialiser cannot execute
      const rhs = text.slice(eq + 3).trim();
      // literals, module constants, and lambdas (generic or not) cannot execute
      const total = /^(\[|null|0|true|false|undefined|DEFAULT_TIMEOUTS|\(|<|async \(|async <)/.test(
        rhs,
      );
      if (!total) offenders.push(`${i + 1}: ${text.trim()}`);
    }
    expect(
      offenders,
      `these run BEFORE the boundary, so a fault in them exits with no run record:\n${offenders.join('\n')}`,
    ).toEqual([]);
  });

  test('each wrapped site pins the kind of its enclosing perform, re-read from source', () => {
    const wrappers = ARTIFACT.sites
      .filter((s) => s.class === 'wrapper')
      .sort((a, b) => lineOf(a) - lineOf(b));
    const kindAt = (line: number): string => {
      for (let i = line - 1; i < line + 2 && i < DRIVER_SRC.length; i += 1) {
        const m = /perform\(\s*'([a-z-]+)'|^\s*'([a-z-]+)',/.exec(DRIVER_SRC[i]);
        if (m) return m[1] ?? m[2];
      }
      return '?';
    };

    const mismatched: string[] = [];
    ARTIFACT.sites
      .filter((s) => s.class === 'wrapped')
      .forEach((site) => {
        const enclosing = wrappers.filter((w) => lineOf(w) < lineOf(site)).pop();
        expect(enclosing, `${site.id} has no enclosing perform`).toBeDefined();
        const kind = kindAt(lineOf(enclosing as Site));
        if (site.producer !== `OF(${kind})`) {
          mismatched.push(`${site.id} pins ${site.producer}, source says OF(${kind})`);
        }
      });
    expect(mismatched, mismatched.join('\n')).toEqual([]);
  });

  test('every named witness exists, and every injected row names one', () => {
    const declared: Record<string, boolean> = {};
    CASES.forEach((c) => {
      declared[c.witness] = true;
    });
    const missing = ARTIFACT.sites
      .filter((s) => s.injection.status === 'injected')
      .map((s) => s.injection.witness as string)
      .filter((w) => !declared[w]);
    expect(
      Array.from(new Set(missing)),
      `the artifact names witnesses that do not exist: ${missing.join(', ')}`,
    ).toEqual([]);

    const undeclared = ARTIFACT.sites.filter((s) => !s.injection || !s.injection.status);
    expect(undeclared.map((s) => s.id)).toEqual([]);
  });

  test('the scope declares the fixture that is actually executed', () => {
    // ROUND-9 BLOCKER 1: driveScripted passes this module's implementation to
    // the real driver, so its faults cross the outer boundary.
    expect(ARTIFACT.scope.declared.join('\n')).toContain('adaptiveStrictDeck.ts');
    expect(ARTIFACT.interior_collapse.per_method.length).toBeGreaterThan(5);
  });

  test('the identity amendment is recorded as proposed, not silently applied', () => {
    expect(ARTIFACT.site_identity.form).toBe('call-edge');
    expect(ARTIFACT.site_identity.amendment_status).toContain('PROPOSED-PENDING');
  });
});

test.describe('per-site fault injection — B4-EXIT-EM (W-E2)', () => {
  CASES.forEach((c) => {
    test(`${c.witness}: ${c.site} ${c.callee} emits its pinned producer and no other`, async () => {
      const driven = await driveScripted({
        screens: c.screens ? c.screens() : SCREENS(),
        manifest: c.manifest ? c.manifest() : MANIFEST,
        wrapDeck: c.at === 'deck' && c.inj ? wrapDeck(c.inj) : undefined,
        beforeStart: c.prep ?? (c.at === 'core' && c.inj ? faultCore(c.inj) : undefined),
        options: c.options,
      });
      const { outcome, runRecord, core } = driven;

      if (c.journalCode === 'skip') {
        expect(outcome.kind).toBe('completed');
        return;
      }

      expect(outcome.kind, JSON.stringify(outcome).slice(0, 300)).toBe('aborted');
      expect(runRecord.operationFailures).toEqual(c.failures);

      // the artifact row for THIS caller AND THIS callee must pin exactly what
      // came out — round-9 blocker 4: line-only lookup with substring matching
      // proved neither the callee nor the producer
      const rows = ARTIFACT.sites.filter((s) => s.caller === c.site && s.callee === c.callee);
      expect(rows.length, `no inventory row for ${c.site} -> ${c.callee}`).toBeGreaterThan(0);
      const pinned = rows.map((s) => s.producer);
      const emitted = c.failures.length > 0 ? `OF(${c.failures[0].kind})` : null;
      if (emitted) {
        expect(pinned, `${c.site} -> ${c.callee} pins ${pinned.join(',')}`).toContain(emitted);
      } else {
        // a stop site: NO operation failure, and the journal already holds it
        expect(runRecord.operationFailures).toEqual([]);
        expect(pinned.join(','), 'a stop site must pin a journal-side producer').toMatch(
          /JR|RP|CE/,
        );
        core.beginSeal();
        core.finishSeal();
        const codes = auditRun(MANIFEST, runRecord, core.snapshot()).map((v) => v.code);
        if (c.journalCode && c.journalCode !== 'any') expect(codes).toContain(c.journalCode);
        expect(codes.length).toBeGreaterThan(0);
      }
    });
  });

  test('call-edge identity is what makes a shared callee single-valued', async () => {
    const asIdentity = await driveScripted({
      wrapDeck: wrapDeck({ method: 'waitForDeckReady', onScreen: 'n:1' }),
    });
    const asReadiness = await driveScripted({
      wrapDeck: wrapDeck({ method: 'waitForDeckReady', onScreen: 'q:1', onCall: 2 }),
    });

    expect(asIdentity.runRecord.operationFailures).toEqual([OF('identity-unresolved', null, 0)]);
    expect(asReadiness.runRecord.operationFailures).toEqual([OF('readiness-timeout', 'q:1', 1)]);
  });

  test('a non-Error rejection is still typed at the boundary', async () => {
    const { outcome, runRecord } = await driveScripted({
      beforeStart: faultCore({ method: 'issueFence', onScreen: 'n:1', value: undefined }),
    });
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([OF('identity-unresolved', null, 0)]);
  });
});

test.describe('interior collapse — where a local catch absorbs the fault (W-E2)', () => {
  // ROUND-9 BLOCKER 1: the artifact claimed interior faults always reach the
  // wrapping perform. These drive the PRODUCTION PO against a real page and
  // show exactly where that is and is not true.
  test('the production waitForDeckReady absorbs its footer wait, by design', async ({ page }) => {
    await page.setContent('<div data-janus-type="janus-mcq">no footer here</div>');
    const deck = new AdaptiveDeckPO(page);
    // the footer never appears; the method still returns, so no fault crosses
    await expect(deck.waitForDeckReady()).resolves.toBeUndefined();
  });

  test('the production readiness primitive does NOT absorb a missing control', async ({ page }) => {
    await page.setContent(
      `<iframe style="width:300px;height:120px" src="data:text/html,${encodeURIComponent(
        '<p>no control</p>',
      )}#buttonwidget"></iframe>`,
    );
    const deck = new AdaptiveDeckPO(page);
    // the swallow that widgetControlReady exists to defeat
    expect(await deck.widgetFrame('buttonwidget', '.button-widget .button')).not.toBeNull();
    expect(await deck.widgetButtonReady('buttonwidget', 750)).toBe(false);
  });

  test('the artifact rules on every driver-reachable PO method', () => {
    const rulings = ARTIFACT.interior_collapse.per_method;
    rulings.forEach((r) => {
      expect(r.ruling, `${r.method} has no ruling`).toMatch(
        /CONSUMED|DELIBERATE ABSORPTION|NOT an absorption|SPLIT/,
      );
    });
    const named = rulings.map((r) => r.method).join(' ');
    ['waitForDeckReady', 'lessonEnded', 'readPartInventory', 'playVideos', 'widgetFrame'].forEach(
      (m) => expect(named).toContain(m),
    );
  });
});

test.describe('emission is load-bearing — W-E3', () => {
  test('deleting the emitted failure loses the violation it carried', async () => {
    const { runRecord, core } = await driveScripted({
      wrapDeck: wrapDeck({ method: 'submitCheck', onScreen: 'q:1' }),
    });
    expect(runRecord.operationFailures).toEqual([OF('check-click-no-effect', 'q:1', 1)]);

    core.beginSeal();
    core.finishSeal();
    const snapshot = core.snapshot();
    const opFailures = (r: RunRecord) =>
      auditRun(MANIFEST, r, snapshot).filter((v) => v.code === 'operation-failure');
    expect(opFailures(runRecord).length).toBe(1);
    expect(opFailures({ ...runRecord, operationFailures: [] }).length).toBe(0);
  });

  test('a stop site that also emitted a failure would double-count', async () => {
    const screens = SCREENS();
    screens[1].checks = [
      { correct: true, results: [event(true, [navTo('next')])], deck: 'stay', broken: 'status' },
    ];
    const { runRecord, core } = await driveScripted({ screens });
    expect(runRecord.operationFailures).toEqual([]);

    core.beginSeal();
    core.finishSeal();
    const snapshot = core.snapshot();
    const honest = auditRun(MANIFEST, runRecord, snapshot);
    const mutant = auditRun(
      MANIFEST,
      { ...runRecord, operationFailures: [OF('check-click-no-effect', 'q:1', 1)] },
      snapshot,
    );
    expect(mutant.length).toBeGreaterThan(honest.length);
  });
});

test.describe('record classes reach the audit — B4-EXIT-MAP (W-E4/W-E5)', () => {
  const kindsFromSource = (): string[] => {
    const src = fs.readFileSync(
      path.join(AUTOMATION, 'src/systems/torus/tasks/AdaptiveOracle.ts'),
      'utf8',
    );
    const decl = /export type OperationFailureKind =([\s\S]*?);/.exec(src);
    expect(decl, 'the OperationFailureKind union moved').not.toBeNull();
    return ((decl as RegExpExecArray)[1].match(/'([a-z-]+)'/g) ?? []).map((s) =>
      s.replace(/'/g, ''),
    );
  };

  /** the closed reason list, re-read from the journal's own source */
  const reasonsFromSource = (): string[] => {
    const src = fs.readFileSync(
      path.join(AUTOMATION, 'src/systems/torus/tasks/AdaptiveJournal.ts'),
      'utf8',
    );
    const decl = /export type FinalizationFailureReason =([\s\S]*?);/.exec(src);
    expect(decl, 'the FinalizationFailureReason union moved').not.toBeNull();
    return ((decl as RegExpExecArray)[1].match(/'([a-z_]+)'/g) ?? []).map((s) =>
      s.replace(/'/g, ''),
    );
  };

  test('every operation-failure kind produces a violation through auditRun', async () => {
    const kinds = kindsFromSource();
    expect(kinds.length).toBeGreaterThan(10);

    const { runRecord, core } = await driveScripted({});
    const snapshot = freeze(core);
    expect(auditRun(MANIFEST, runRecord, snapshot)).toEqual([]);

    const unmapped = kinds.filter((kind) => {
      const poisoned: RunRecord = {
        ...runRecord,
        operationFailures: [OF(kind as OperationFailure['kind'], 'q:1', 1)],
      };
      return (
        auditRun(MANIFEST, poisoned, snapshot).filter((v) => v.code === 'operation-failure')
          .length === 0
      );
    });
    expect(unmapped, `record classes that reach no violation: ${unmapped.join(', ')}`).toEqual([]);
  });

  test('EVERY finalization-failure reason reaches a violation naming it', async () => {
    // ROUND-9 BLOCKER 5: the round-8 "completed-failure" test called
    // beginSeal/finishSeal and was an ordinary sealed snapshot. This one
    // actually terminalizes, and it crosses the WHOLE closed reason list.
    const reasons = reasonsFromSource();
    expect(reasons.length).toBe(5);

    const unmapped: string[] = [];
    for (const reason of reasons) {
      const { runRecord, core } = await driveScripted({});
      core.enterTerminalization(reason as FinalizationFailureReason);
      core.markFrozenCompletedFailure();
      const snapshot = core.snapshot();
      expect(snapshot.freezeFlavor).toBe('completed-failure');

      const violations = auditRun(MANIFEST, runRecord, snapshot);
      const named = violations.filter(
        (v) =>
          v.code === 'terminal-obligation' &&
          (v.facts as { detail?: string; reason?: string }).detail === 'finalization-misbehaved' &&
          (v.facts as { reason?: string }).reason === reason,
      );
      if (named.length === 0) unmapped.push(reason);
    }
    expect(
      unmapped,
      `finalization reasons with no audit violation: ${unmapped.join(', ')}`,
    ).toEqual([]);
  });

  test('a freeze timeout is positive evidence, not a silent bail', async () => {
    const { runRecord, core } = await driveScripted({});
    core.markFreezeTimeout();
    core.beginSeal();
    core.finishSeal();
    const codes = auditRun(MANIFEST, runRecord, core.snapshot()).map((v) => v.code);
    expect(codes).toContain('freeze-timeout');
  });

  test('an open pre-completion window with its record SUPPRESSED still cannot audit clean', () => {
    // ROUND-9 BLOCKER 5: the round-8 case left the operation failure in place,
    // so it never exercised the zero-positive boundary at all.
    return driveScripted({
      wrapDeck: wrapDeck({ method: 'waitForCheckEnabled', onScreen: 'q:1' }),
    }).then(({ runRecord, core }) => {
      expect(runRecord.operationFailures).toEqual([OF('readiness-timeout', 'q:1', 1)]);
      core.beginSeal();
      core.finishSeal();
      const snapshot = core.snapshot();

      const suppressed: RunRecord = { ...runRecord, operationFailures: [] };
      const violations = auditRun(MANIFEST, suppressed, snapshot);
      // absence conclusions are gated on the open window (§3.2), so no
      // cardinality violation fires — the seal clause is what catches it
      expect(violations.length, 'a suppressed record must not audit clean').toBeGreaterThan(0);
      expect(violations.map((v) => v.code)).toContain('seal-without-evidence');
    });
  });
});

test.describe('emission provenance — W-E6', () => {
  test('a hand-built run record does not satisfy what an emitted one does', async () => {
    const { runRecord, core } = await driveScripted({});
    const snapshot = freeze(core);
    expect(auditRun(MANIFEST, runRecord, snapshot)).toEqual([]);

    const forged: RunRecord = {
      ...runRecord,
      permits: runRecord.permits.map((p) => ({ ...p, seq: p.seq + 1_000 })),
    };
    const codes = auditRun(MANIFEST, forged, snapshot).map((v) => v.code);
    expect(codes.length, 'a fabricated stamp must not audit as an emitted one').toBeGreaterThan(0);
  });

  test('the inventory records the reviewer comparison and every round-9 disposition', () => {
    const ids = ARTIFACT.reviewer_comparison.findings.map((f) => f.id);
    ['F-1', 'F-2', 'F-3', 'R9-1', 'R9-2', 'R9-3', 'R9-4', 'R9-5'].forEach((id) =>
      expect(ids).toContain(id),
    );
    ARTIFACT.reviewer_comparison.findings.forEach((f) => {
      expect(f.disposition.length).toBeGreaterThan(0);
    });
  });
});

test.describe('exit inventory — the frozen run stays green', () => {
  test('no injection leaks into an uninjected run', async () => {
    const { outcome, runRecord, core } = await driveScripted({});
    expect(outcome.kind).toBe('completed');
    expect(runRecord.operationFailures).toEqual([]);
    expect(auditRun(MANIFEST, runRecord, freeze(core))).toEqual([]);
  });
});

test.describe('routed layer — injectable boundary, contract-kind AST, bidirectional (W-E0a, rounds 2-5)', () => {
  const MODULE_REL = 'src/systems/torus/tasks/AdaptiveStrictGatedRun.ts';
  const SPEC_REL = 'tests/torus/student_delivery/lote-plate-tectonics.spec.ts';
  const ROUTED = ARTIFACT as unknown as {
    routed_layer: {
      module_sites: Array<{
        line: number;
        callee: string;
        kind: string;
        region: string;
        producer: string;
      }>;
      module_non_exit_closure: Array<{
        line: number;
        callee: string;
        kind: string;
        region: string;
      }>;
      spec_residual_sites: Array<{
        line: number;
        callee: string;
        kind: string;
        region: string;
        producer: string;
      }>;
      spec_residual_non_exit_closure: Array<{
        line: number;
        callee: string;
        kind: string;
        region: string;
      }>;
    };
  };
  const NON_EXIT = [
    'locally-handled await (non-exit; recorded for closure)',
    'return (success path; recorded for closure)',
  ];

  type RoutedRow = { line: number; callee: string; kind: string; region: string };

  /** Contract-kind derivation shared by both targets (hardened per round 5's
   * probes: argless .catch and .then(ok, undefined) do NOT handle; awaited
   * parenthesized/ternary branches classify; returns/finally recorded). */
  function derive(
    rel: string,
    target: 'module' | 'spec',
  ): { rows: RoutedRow[]; catchClause: ts.CatchClause | null } {
    const text = fs.readFileSync(path.join(AUTOMATION, rel), 'utf8');
    const sf = ts.createSourceFile('t.ts', text, ts.ScriptTarget.ES2020, true);
    const lineOf = (n: ts.Node) => sf.getLineAndCharacterOfPosition(n.getStart(sf)).line + 1;
    const endOf = (n: ts.Node) => sf.getLineAndCharacterOfPosition(n.getEnd()).line + 1;

    let body: ts.Node | null = null;
    if (target === 'module') {
      const findFn = (node: ts.Node): void => {
        if (ts.isFunctionDeclaration(node) && node.name?.text === 'runGatedLote') {
          body = node.body ?? null;
          return;
        }
        ts.forEachChild(node, findFn);
      };
      findFn(sf);
    } else {
      const findTest = (node: ts.Node): void => {
        if (
          ts.isCallExpression(node) &&
          node.expression.getText(sf) === 'test' &&
          node.arguments[0]?.getText(sf).includes('student completes the plate tectonics')
        ) {
          body = (node.arguments[1] as ts.ArrowFunction).body;
          return;
        }
        ts.forEachChild(node, findTest);
      };
      findTest(sf);
    }
    if (!body) throw new Error(`${target} body not found in ${rel}`);
    const root: ts.Node = body;

    let tryStmt: ts.TryStatement | null = null;
    const findTry = (node: ts.Node): void => {
      if (ts.isTryStatement(node) && !tryStmt) {
        tryStmt = node;
        return;
      }
      ts.forEachChild(node, findTry);
    };
    findTry(root);
    const found: ts.TryStatement | null = tryStmt;

    const bodyStart = lineOf(root);
    const bodyEnd = endOf(root);
    const regions = found
      ? {
          tryStart: lineOf(found.tryBlock),
          tryEnd: endOf(found.tryBlock),
          catchStart: lineOf(found.catchClause as ts.CatchClause),
          catchEnd: endOf(found.catchClause as ts.CatchClause),
        }
      : null;
    const regionOf = (l: number): string | null => {
      if (!regions) return l >= bodyStart && l <= bodyEnd ? 'body' : null;
      if (l >= regions.catchStart && l <= regions.catchEnd) return 'catch';
      if (l >= regions.tryStart && l <= regions.tryEnd) return 'try';
      if (l >= bodyStart && l < regions.tryStart) return 'pre';
      if (l > regions.catchEnd && l <= bodyEnd) return 'post';
      return null;
    };

    const consumed = new Set<ts.Node>();
    const rows: RoutedRow[] = [];
    const push = (n: ts.Node, callee: string, kind: string) => {
      const region = regionOf(lineOf(n));
      if (region) rows.push({ line: lineOf(n), callee, kind, region });
    };

    const markThrows = (node: ts.Node): void => {
      if (ts.isThrowStatement(node) && node.expression) {
        push(node, `throw ${node.expression.getText(sf).split('\n')[0].slice(0, 60)}`, 'throw');
        const absorb = (inner: ts.Node): void => {
          consumed.add(inner);
          ts.forEachChild(inner, absorb);
        };
        absorb(node.expression);
      }
      ts.forEachChild(node, markThrows);
    };
    markThrows(root);

    const isRealHandler = (arg: ts.Expression): boolean =>
      ts.isArrowFunction(arg) || ts.isFunctionExpression(arg);
    const markAwaits = (node: ts.Node): void => {
      if (ts.isAwaitExpression(node)) {
        let inner: ts.Expression | null = node.expression;
        let handled = false;
        for (;;) {
          if (!inner) break;
          consumed.add(inner);
          if (
            ts.isCallExpression(inner) &&
            ts.isPropertyAccessExpression(inner.expression) &&
            ((inner.expression.name.text === 'catch' &&
              inner.arguments.length >= 1 &&
              isRealHandler(inner.arguments[0])) ||
              (inner.expression.name.text === 'then' &&
                inner.arguments.length === 2 &&
                isRealHandler(inner.arguments[1])))
          ) {
            handled = true;
            inner = inner.expression.expression;
            continue;
          }
          if (
            ts.isCallExpression(inner) &&
            ts.isPropertyAccessExpression(inner.expression) &&
            (inner.expression.name.text === 'catch' || inner.expression.name.text === 'then')
          ) {
            inner = inner.expression.expression;
            continue;
          }
          if (ts.isParenthesizedExpression(inner)) {
            inner = inner.expression;
            continue;
          }
          if (ts.isConditionalExpression(inner)) {
            [inner.whenTrue, inner.whenFalse].forEach((branch) => {
              let b: ts.Expression = branch;
              while (ts.isParenthesizedExpression(b)) b = b.expression;
              if (ts.isCallExpression(b) || ts.isNewExpression(b)) {
                consumed.add(b);
                push(
                  b,
                  b.expression!.getText(sf).replace(/\s+/g, ''),
                  handled
                    ? 'locally-handled await (non-exit; recorded for closure)'
                    : 'rejecting await without local handler',
                );
              }
            });
            inner = null;
            break;
          }
          break;
        }
        if (inner && (ts.isCallExpression(inner) || ts.isNewExpression(inner))) {
          push(
            inner,
            inner.expression!.getText(sf).replace(/\s+/g, ''),
            handled
              ? 'locally-handled await (non-exit; recorded for closure)'
              : 'rejecting await without local handler',
          );
        }
      }
      ts.forEachChild(node, markAwaits);
    };
    markAwaits(root);

    if (found) {
      const cc = found.catchClause as ts.CatchClause;
      push(cc, `catch (${cc.variableDeclaration?.getText(sf) ?? ''})`, 'catch branch');
      if (found.finallyBlock) push(found.finallyBlock, 'finally', 'finally/cleanup failure');
    }
    const markReturns = (node: ts.Node): void => {
      if (ts.isReturnStatement(node)) {
        const l = lineOf(node);
        const inCatch = regions !== null && l >= regions.catchStart && l <= regions.catchEnd;
        push(
          node,
          `return ${node.expression ? node.expression.getText(sf).split('\n')[0].slice(0, 40) : ''}`,
          inCatch ? 'failure-path early return' : 'return (success path; recorded for closure)',
        );
      }
      ts.forEachChild(node, markReturns);
    };
    markReturns(root);

    const walk = (node: ts.Node): void => {
      if ((ts.isCallExpression(node) || ts.isNewExpression(node)) && !consumed.has(node)) {
        push(
          node,
          ts.isNewExpression(node)
            ? `new ${node.expression.getText(sf)}`
            : node.expression.getText(sf).replace(/\s+/g, ''),
          'throw',
        );
      }
      ts.forEachChild(node, walk);
    };
    walk(root);

    rows.sort((a, b) => a.line - b.line || a.callee.localeCompare(b.callee));
    return { rows, catchClause: found ? (found.catchClause as ts.CatchClause) : null };
  }

  const key = (r: RoutedRow) => `${r.line}|${r.callee}|${r.kind}|${r.region}`;

  test('the module EXIT table equals the contract-kind derivation, both directions (W-E0a)', () => {
    const all = derive(MODULE_REL, 'module').rows;
    const derivedExits = all.filter((r) => !NON_EXIT.includes(r.kind)).map(key);
    const derivedClosure = all.filter((r) => NON_EXIT.includes(r.kind)).map(key);
    expect(ROUTED.routed_layer.module_sites.map(key).sort()).toEqual(derivedExits.sort());
    expect(ROUTED.routed_layer.module_non_exit_closure.map(key).sort()).toEqual(
      derivedClosure.sort(),
    );
    // every EXIT row pins exactly one producer, named for its region
    ROUTED.routed_layer.module_sites.forEach((r) => {
      expect(typeof r.producer, `${r.callee} at :${r.line} has no producer`).toBe('string');
      expect(r.producer.length).toBeGreaterThan(10);
    });
  });

  test('the spec residual equals its derivation, both directions, and arms nothing', () => {
    const derivation = derive(SPEC_REL, 'spec');
    const derived = derivation.rows.filter((r) => !NON_EXIT.includes(r.kind)).map(key);
    const declared = ROUTED.routed_layer.spec_residual_sites.map(key);
    expect([...declared].sort()).toEqual([...derived].sort());
    ROUTED.routed_layer.spec_residual_sites.forEach((r) => {
      expect(typeof r.producer).toBe('string');
    });
    derivation.rows.forEach((r) => {
      expect(r.callee, `spec residual arms: ${r.callee}`).not.toMatch(/^arm[A-Z]|^new Adaptive/);
      expect(r.kind).not.toBe('catch branch');
    });
    // the ONLY awaited exit in the spec is the boundary call itself
    const awaits = derivation.rows.filter((r) => r.kind.startsWith('rejecting await'));
    expect(awaits.map((r) => r.callee)).toEqual(['runGatedLote']);
  });

  test('the module catch rethrows the SAME error and guards every cleanup await', () => {
    const { rows, catchClause } = derive(MODULE_REL, 'module');
    expect(catchClause).not.toBeNull();
    const cc = catchClause as ts.CatchClause;
    const statements = cc.block.statements;
    const last = statements[statements.length - 1];
    expect(ts.isThrowStatement(last), 'the catch must END on the rethrow').toBe(true);
    expect((last as ts.ThrowStatement).expression.getText()).toBe('boundaryError');
    rows
      .filter((r) => r.region === 'catch' && r.kind.startsWith('rejecting await'))
      .forEach((r) => {
        throw new Error(`unguarded cleanup await in the module catch: ${r.callee} at :${r.line}`);
      });
    const interior = rows
      .filter((r) => r.region === 'catch' && r.kind === 'throw' && !r.callee.startsWith('throw '))
      .map((r) => r.callee);
    interior.forEach((callee) =>
      expect(
        ['failureText', 'poison?.fired', 'deps.log', 'deps.warn', 'quietly'].includes(callee),
        `catch-interior call outside the allowlist: ${callee}`,
      ).toBe(true),
    );
    // the logging handlers themselves must be quietly()-wrapped (total by
    // construction — round-6 blocker 11)
    const catchText = catchClause!.getText();
    expect(catchText).toContain('quietly(() =>');
    expect(catchText.match(/quietly\(/g)!.length).toBeGreaterThanOrEqual(2);
  });
});
