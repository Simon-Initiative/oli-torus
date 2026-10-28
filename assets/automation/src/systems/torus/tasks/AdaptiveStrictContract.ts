/**
 * Strict adaptive-driver contract (MER-5674 §10 step 1).
 *
 * Identity: a screen is `model.id` (the archive's `custom.sequenceId`),
 * correlated to evaluation traffic by the live `attemptGuid`. The manifest's
 * resource_id is the ARCHIVE activity id — imports remap activity ids, so it
 * is cross-checked offline against the archive, while the walk records the
 * live `model.resourceId` and enforces its run-internal consistency. No
 * rendered-text fallback.
 *
 * Receipt: every answered screen yields a receipt naming the directive that
 * answered it plus the canonical submission expected in the evaluation
 * request body — part path suffixes and values, dynamic prefixes excluded.
 *
 * Transition: derived from the evaluation response's own actions, mirroring
 * DeckLayoutFooter's default single-event path — feedback present means an
 * acknowledgement is legal and either navigates (queued target) or re-checks
 * (a second, expected evaluation); navigation without feedback
 * auto-navigates; target `endOfLesson` is terminal; neither is a
 * mutation-only stay. In delivery mode every check PUTs an evaluation
 * regardless of screen role, so evaluation counts are per-role expectations.
 *
 * Ledger invariants (asserted in §10 step 10): ordered full coverage of the
 * manifest, exact cardinality, per-role evaluation counts with attempt-GUID
 * and payload match, true verdict per graded screen, no undeclared screens,
 * no unexpected evaluations, terminal transition only at the last screen.
 */

export type ScreenRole = 'graded' | 'content' | 'navigation';

/**
 * Text matchers in directives (`pick`, `picks`, `labels_match`, matching
 * `links`) are case-insensitive REGEX SOURCES by key convention — the merged
 * private keys escape their own metacharacters (e.g. `more dense\\.`), and
 * the same convention carries into strict manifests deliberately.
 */
export type AnswerDirective =
  | {
      kind: 'frame_selects';
      src_fragment: string;
      ready_selector: string;
      values: Record<string, string>;
      required_option?: string;
    }
  | {
      kind: 'custom_dnd';
      src_fragment: string;
      detect: string;
      placements: Array<{ item: string; zone: string }>;
    }
  | { kind: 'grouping'; src_fragment: string; placements: Array<{ item: string; group: string }> }
  | { kind: 'ordering'; src_fragment: string; order: string[] }
  | { kind: 'matching'; src_fragment: string; links: Array<{ left: string; right: string }> }
  | { kind: 'native_dropdowns'; picks: string[]; part_id?: string }
  /** `part_id` scopes the receipt when a screen renders several fill-blanks parts */
  | { kind: 'fib_labels'; labels: string[]; part_id?: string }
  /** `part_id` scopes both the click and the receipt when a screen has several janus-mcq parts */
  | { kind: 'mcq_radio'; labels_match: string; pick: string; part_id?: string }
  | { kind: 'mcq_checkboxes'; picks: string[]; part_id?: string }
  | { kind: 'text_input'; value: string };

export type ScreenAction = { kind: 'in_widget_button'; src_fragment: string };

export type ManifestScreen = {
  id: string;
  resource_id: number;
  role: ScreenRole;
  answers?: AnswerDirective[];
  action?: ScreenAction;
};

export type ScreenIdentity = { id: string; resourceId: number; attemptGuid: string };

/**
 * Expected part paths are suffix-matched: live paths carry dynamic prefixes.
 * `value` compares exactly (JSON equality); `value_matches` is a
 * case-insensitive regex over the stringified value (option texts flatten
 * markup and whitespace unpredictably); `path_prefix` asserts presence only —
 * CAPI widget variables are not statically derivable, so those receipts prove
 * the widget's state cluster was submitted at all.
 */
export type ExpectedPart =
  | { path: string; value: unknown }
  | { path: string; value_matches: string }
  | { path_prefix: string }
  /**
   * at least `min_count` (default 1) distinct submitted parts under this
   * prefix must carry a value matching the regex — cardinality matters when
   * the same answer label legitimately fills several blanks
   */
  | { path_prefix: string; value_matches: string; min_count?: number };
export type ExpectedSubmission = ExpectedPart[];

export type AnswerReceipt = {
  screenId: string;
  /** the directive kind(s) that answered the screen, '+'-joined when several */
  directive: string;
  readback: string;
  expected: ExpectedSubmission;
  /**
   * CAPI widget state reaches the deck asynchronously (iframe postMessage →
   * applyState → redux) and the evaluation snapshots that state at check
   * time; these parts must appear in a deferred PATCH save BEFORE the check
   * is clicked, or the submission would carry the widget's initial state.
   */
  awaitSaved?: ExpectedSubmission;
};

export type CheckActions = {
  correct: boolean;
  score?: number;
  out_of?: number;
  results?: Array<{
    params?: { actions?: Array<{ type: string; params?: Record<string, unknown> }> };
  }>;
};

export type DerivedTransition =
  | { kind: 'auto-navigate'; target: string }
  | { kind: 'terminal' }
  | { kind: 'feedback'; ack: { kind: 'navigate'; target: string } | { kind: 'recheck' } }
  | { kind: 'none' };

export type EvaluationRecord = {
  attemptGuid: string;
  /** sequenceId prefix of the submitted part paths — the screen this request belongs to */
  screenId: string | null;
  /** any other sequenceId prefixes in the same submission (mixed traffic) */
  otherScreenIds: string[];
  /** server-generated feedback text; the deck opens feedback for it too */
  llmFeedback: { text?: string } | null;
  /**
   * finalize saves PUT the same URL as evaluations (response body tells them
   * apart); deferred part-state saves PATCH the /active variant
   */
  kind: 'evaluation' | 'finalize' | 'save' | 'unknown';
  url: string;
  partInputs: unknown[] | null;
  requestAt: number;
  responseAt: number | null;
  /**
   * Monotonic per-observer event order — request and response stamps share
   * one counter, so ordering between any two observed events is strict and
   * never ambiguous the way millisecond clocks are.
   */
  requestSeq: number;
  responseSeq: number | null;
  status: number | null;
  actions: CheckActions | null;
  correct: boolean | null;
  parseError: string | null;
  parsed: boolean;
};

/**
 * An observed attempt rotation: POST /activity_attempt/<targetGuid> minting a
 * fresh attempt. The minted guid is server-generated, so a later evaluation
 * submitted under it proves it started after this response — the causal
 * anchor the navigation licence requires.
 */
export type AttemptCreation = {
  targetGuid: string;
  newGuid: string | null;
  requestSeq: number;
  responseSeq: number | null;
  status: number | null;
  parsed: boolean;
};

export type LedgerEntry = {
  screenId: string;
  resourceId: number;
  attemptGuid: string;
  role: ScreenRole;
  receipt: AnswerReceipt | null;
  evaluationCount: number;
  /**
   * The exact number of evaluations the walk itself licensed (1, or 2 when a
   * legal feedback re-check occurred). When present the ledger requires
   * equality — an accidental extra submission can never hide inside a range.
   */
  expectedEvaluations?: number;
  verdict: boolean | null;
  payloadMatch: boolean | null;
  transition: DerivedTransition | null;
};

const ROLES: readonly ScreenRole[] = ['graded', 'content', 'navigation'];

const isNonEmptyString = (v: unknown): v is string => typeof v === 'string' && v.length > 0;
const isStringArray = (v: unknown): v is string[] =>
  Array.isArray(v) && v.length > 0 && v.every((x) => isNonEmptyString(x));
const isPairArray = (v: unknown, left: string, right: string): boolean =>
  Array.isArray(v) &&
  v.length > 0 &&
  v.every(
    (x) =>
      !!x &&
      typeof x === 'object' &&
      isNonEmptyString((x as Record<string, unknown>)[left]) &&
      isNonEmptyString((x as Record<string, unknown>)[right]),
  );

const DIRECTIVE_VALIDATORS: Record<string, (d: Record<string, unknown>) => boolean> = {
  frame_selects: (d) =>
    isNonEmptyString(d.src_fragment) &&
    isNonEmptyString(d.ready_selector) &&
    !!d.values &&
    typeof d.values === 'object' &&
    Object.values(d.values).length > 0 &&
    Object.values(d.values).every((v) => typeof v === 'string'),
  custom_dnd: (d) =>
    isNonEmptyString(d.src_fragment) &&
    isNonEmptyString(d.detect) &&
    isPairArray(d.placements, 'item', 'zone'),
  grouping: (d) => isNonEmptyString(d.src_fragment) && isPairArray(d.placements, 'item', 'group'),
  ordering: (d) => isNonEmptyString(d.src_fragment) && isStringArray(d.order),
  matching: (d) => isNonEmptyString(d.src_fragment) && isPairArray(d.links, 'left', 'right'),
  native_dropdowns: (d) => isStringArray(d.picks),
  fib_labels: (d) => isStringArray(d.labels),
  mcq_radio: (d) => isNonEmptyString(d.labels_match) && isNonEmptyString(d.pick),
  mcq_checkboxes: (d) => isStringArray(d.picks),
  text_input: (d) => isNonEmptyString(d.value),
};

const fail = (msg: string): never => {
  throw new Error(`invalid strict manifest: ${msg}`);
};

export function validateManifest(raw: unknown): ManifestScreen[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    fail('screens must be a non-empty array (strict mode requires a per-screen manifest)');
  }
  const screens = raw as Array<Record<string, unknown>>;
  const seen = new Set<string>();

  screens.forEach((s, i) => {
    const at = `screens[${i}]`;
    if (!s || typeof s !== 'object' || Array.isArray(s)) fail(`${at} is not an object`);
    if (!isNonEmptyString(s.id)) fail(`${at}.id must be a non-empty string`);
    const id = s.id as string;
    if (seen.has(id)) fail(`duplicate screen id "${id}"`);
    seen.add(id);
    if (typeof s.resource_id !== 'number') fail(`${at} ("${id}").resource_id must be a number`);
    if (!ROLES.includes(s.role as ScreenRole)) {
      fail(`${at} ("${id}").role must be one of ${ROLES.join('|')}`);
    }

    if (s.role === 'graded') {
      if (!Array.isArray(s.answers) || s.answers.length === 0) {
        fail(`${at} ("${id}") is graded and must declare a non-empty answers array`);
      }
      (s.answers as Array<Record<string, unknown>>).forEach((a, j) => {
        const dat = `${at}.answers[${j}]`;
        if (!a || typeof a !== 'object') fail(`${dat} is not an object`);
        const validator = DIRECTIVE_VALIDATORS[a.kind as string];
        if (!validator) fail(`${dat} has unknown kind "${String(a.kind)}"`);
        if (!validator(a))
          fail(`${dat} (${String(a.kind)}) is missing or mistypes required fields`);
      });
    } else if (s.answers !== undefined) {
      fail(`${at} ("${id}") is ${String(s.role)} and must not declare answers`);
    }

    if (s.role === 'navigation') {
      const action = s.action as Record<string, unknown> | undefined;
      if (!action || action.kind !== 'in_widget_button' || !isNonEmptyString(action.src_fragment)) {
        fail(`${at} ("${id}") is navigation and must declare an in_widget_button action`);
      }
    } else if (s.action !== undefined) {
      fail(`${at} ("${id}") is ${String(s.role)} and must not declare an action`);
    }
  });

  return raw as ManifestScreen[];
}

/**
 * Live identity resolution matches by sequenceId only: the manifest's
 * resource_id is the ARCHIVE activity id, valid for offline validation, but
 * a course import remaps activity ids — the live resourceId differs by
 * design. The walk enforces run-internal consistency (one live resourceId
 * per sequenceId) instead.
 */
export function resolveManifestScreen(
  screens: ManifestScreen[],
  identity: ScreenIdentity,
): ManifestScreen {
  const screen = screens.find((s) => s.id === identity.id);
  if (!screen) {
    throw new Error(
      `undeclared screen "${identity.id}" (live resource ${identity.resourceId}) is not in the strict manifest`,
    );
  }
  return screen;
}

type SubmittedPair = { path: string; value: unknown };

/**
 * Evaluation PUTs nest the part map under `response.input`; deferred PATCH
 * saves inline it directly under `response`. Both shapes carry
 * `{path, value}` items.
 */
export function extractSubmittedPairs(partInputs: unknown[] | null): SubmittedPair[] {
  if (!partInputs) return [];
  const pairs: SubmittedPair[] = [];
  for (const part of partInputs) {
    const response = (part as { response?: Record<string, unknown> | null })?.response;
    if (!response || typeof response !== 'object') continue;
    const input =
      response.input && typeof response.input === 'object'
        ? (response.input as Record<string, unknown>)
        : response;
    for (const item of Object.values(input)) {
      const entry = item as { path?: unknown; value?: unknown } | null;
      if (entry && typeof entry.path === 'string') {
        pairs.push({ path: entry.path, value: entry.value });
      }
    }
  }
  return pairs;
}

const sameValue = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

const partSatisfied = (pairs: SubmittedPair[], e: ExpectedPart): boolean => {
  if ('path_prefix' in e) {
    const underPrefix = pairs.filter((p) => p.path.includes(e.path_prefix));
    if (!('value_matches' in e)) return underPrefix.length > 0;
    const re = new RegExp(e.value_matches, 'i');
    const matched = underPrefix.filter((p) => re.test(String(p.value)));
    return matched.length >= (e.min_count ?? 1);
  }
  const atPath = pairs.filter((p) => p.path === e.path || p.path.endsWith(e.path));
  if ('value_matches' in e) {
    const re = new RegExp(e.value_matches, 'i');
    return atPath.some((p) => re.test(String(p.value)));
  }
  return atPath.some((p) => sameValue(p.value, e.value));
};

export function missingExpectedPaths(
  pairs: SubmittedPair[],
  expected: ExpectedSubmission,
): string[] {
  return expected
    .filter((e) => !partSatisfied(pairs, e))
    .map((e) => ('path_prefix' in e ? `${e.path_prefix}*` : e.path));
}

export function deriveTransition(
  actions: CheckActions,
  llmFeedback?: { text?: string } | null,
): DerivedTransition {
  const acts = actions.results?.[0]?.params?.actions ?? [];
  const feedback = acts.filter((a) => a.type === 'feedback');
  const nav = acts.filter((a) => a.type === 'navigation');
  const target = nav.length > 0 ? String(nav[0].params?.target ?? '') : '';

  if (feedback.length > 0 || llmFeedback?.text) {
    return {
      kind: 'feedback',
      ack: nav.length > 0 ? { kind: 'navigate', target } : { kind: 'recheck' },
    };
  }
  if (nav.length > 0) {
    return target === 'endOfLesson' ? { kind: 'terminal' } : { kind: 'auto-navigate', target };
  }
  return { kind: 'none' };
}

/**
 * The strict per-screen oracle: exactly one evaluation, answered by the
 * server with 2xx, a boolean `actions.correct === true`, a non-empty
 * submitted payload, and — when a receipt provides one — every expected
 * part present with its expected value. Failure messages name part paths
 * only, never answer values: traces run with the key, which is private.
 */
/**
 * Per-role evaluation expectations. In delivery mode every footer check PUTs
 * an evaluation regardless of role, so content screens evaluate too; graded
 * screens may legally evaluate twice when correct feedback carries no queued
 * navigation and the acknowledgement re-checks. A navigation screen's
 * in-widget button can itself trigger checks, and the first can fire before
 * the widget's state lands (observed on the LotE cover: wrong verdict, deck
 * spawns a fresh attempt, immediate re-check is correct and navigates) — so
 * up to two evaluations, verdict unasserted.
 */
export const ROLE_EVALUATIONS: Record<
  ScreenRole,
  { min: number; max: number; assertVerdict: boolean }
> = {
  graded: { min: 1, max: 2, assertVerdict: true },
  content: { min: 1, max: 1, assertVerdict: false },
  navigation: { min: 0, max: 2, assertVerdict: false },
};

/** Redacted ledger rendering: identities, counts and kinds — never values. */
export function formatLedger(ledger: LedgerEntry[]): string {
  const lines = ledger.map((e, i) => {
    const t = e.transition ? e.transition.kind : 'none-observed';
    return (
      `${String(i).padStart(2)} ${e.screenId} role=${e.role} evals=${e.evaluationCount} ` +
      `verdict=${String(e.verdict)} payloadMatch=${String(e.payloadMatch)} transition=${t}`
    );
  });
  return lines.join('\n');
}

export function assertLedger(ledger: LedgerEntry[], screens: ManifestScreen[]): void {
  const bail = (msg: string): never => {
    throw new Error(`strict ledger violation: ${msg}\n${formatLedger(ledger)}`);
  };

  if (ledger.length !== screens.length) {
    bail(`visited ${ledger.length} screens, manifest declares ${screens.length}`);
  }
  ledger.forEach((entry, i) => {
    const declared = screens[i];
    if (entry.screenId !== declared.id) {
      bail(`position ${i} visited "${entry.screenId}", manifest declares "${declared.id}"`);
    }
    if (entry.role !== declared.role) {
      bail(
        `screen "${entry.screenId}" recorded role ${entry.role}, manifest says ${declared.role}`,
      );
    }

    const expected = ROLE_EVALUATIONS[entry.role];
    if (entry.role === 'navigation') {
      // the widget's own check dance is not licensed click-by-click
      if (entry.evaluationCount < expected.min || entry.evaluationCount > expected.max) {
        bail(
          `screen "${entry.screenId}" (navigation) saw ${entry.evaluationCount} evaluation(s), ` +
            `expected ${expected.min}-${expected.max}`,
        );
      }
    } else if (entry.expectedEvaluations === undefined) {
      // fail closed: a submitting screen without an explicit licence cannot
      // fall back to a permissive range
      bail(
        `screen "${entry.screenId}" (${entry.role}) recorded no licensed evaluation count ` +
          `(saw ${entry.evaluationCount})`,
      );
    } else if (entry.evaluationCount !== entry.expectedEvaluations) {
      bail(
        `screen "${entry.screenId}" (${entry.role}) saw ${entry.evaluationCount} evaluation(s), ` +
          `the walk licensed exactly ${entry.expectedEvaluations}`,
      );
    }
    if (expected.assertVerdict) {
      if (entry.receipt === null) bail(`graded screen "${entry.screenId}" has no answer receipt`);
      if (entry.verdict !== true) {
        bail(`graded screen "${entry.screenId}" verdict=${String(entry.verdict)}`);
      }
      if (entry.payloadMatch !== true) {
        bail(`graded screen "${entry.screenId}" payloadMatch=${String(entry.payloadMatch)}`);
      }
    }

    const isLast = i === ledger.length - 1;
    const isTerminal = entry.transition?.kind === 'terminal';
    if (isTerminal && !isLast) {
      bail(`screen "${entry.screenId}" at position ${i} is terminal before the last screen`);
    }
    // a lesson may end via an explicit endOfLesson target OR by navigating
    // "next" off its final screen, where the deck finalizes; the walk
    // separately asserts the lesson actually ended
    if (isLast && !isTerminal && entry.transition?.kind !== 'auto-navigate') {
      bail(
        `last screen "${entry.screenId}" ended on ${entry.transition?.kind ?? 'no transition'}, ` +
          `expected terminal or auto-navigate`,
      );
    }
  });
}

export function verifyScreenEvaluation(opts: {
  screenId: string;
  records: EvaluationRecord[];
  expected?: ExpectedSubmission;
  attemptGuid?: string;
}): void {
  const { screenId, records, expected, attemptGuid } = opts;
  const bail = (msg: string): never => {
    throw new Error(`[strict ${screenId}] ${msg}`);
  };

  if (records.length === 0) bail('no evaluation request observed');
  if (records.length > 1) {
    bail(`${records.length} evaluation requests observed, expected exactly one`);
  }
  const r = records[0];
  if (attemptGuid && r.attemptGuid !== attemptGuid) {
    bail(`evaluation belongs to attempt ${r.attemptGuid}, expected ${attemptGuid}`);
  }
  if (r.responseAt === null) bail('evaluation request received no response');
  if (r.status === null || r.status < 200 || r.status >= 300) {
    bail(`evaluation returned status ${String(r.status)}`);
  }
  if (r.parseError) bail(`evaluation unusable: ${r.parseError}`);
  if (r.correct !== true) bail(`server verdict correct=${String(r.correct)}`);

  const pairs = extractSubmittedPairs(r.partInputs);
  if (pairs.length === 0) bail('submitted partInputs carry no part responses');
  if (expected && expected.length > 0) {
    const missing = missingExpectedPaths(pairs, expected);
    if (missing.length > 0) {
      bail(`submitted payload is missing expected parts: ${missing.join(', ')}`);
    }
  }
}
