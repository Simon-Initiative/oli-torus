/**
 * Manifest v2 (spec §3.8): two layers replacing the v1 `screens` array —
 * reusable SCREEN DEFINITIONS (identity, role, local operations, grading
 * expectations) and a SCENARIO (the ordered route program for one run).
 * Values and predicates live only in screen definitions; scenario steps hold
 * operation REFERENCES, so map and scenario cannot drift.
 *
 * Predicates are a typed AST over a CLOSED operator set. Names follow the
 * production surface verbatim (json-rules-engine defaults plus the module
 * operators registered on top, `rules-engine.ts:40-53`); truth conditions are
 * NORMATIVE from `assets/src/adaptivity/operators/*.ts` — the matchers here
 * mirror those modules, never re-derive. An unknown operator or a
 * type-mismatched or empty condition argument fails manifest validation by
 * name.
 */

export type ScreenRole = 'graded' | 'content' | 'navigation';
export type GateKind = 'carousel_view' | 'flashcard_flip_all' | 'video_start';
export type ExpectedVerdict = 'correct' | 'incorrect';

export const PREDICATE_OPERATORS = [
  'equal',
  'notEqual',
  'contains',
  'notContains',
  'containsAnyOf',
  'notContainsAnyOf',
  'containsOnly',
  'greaterThan',
  'greaterThanInclusive',
  'lessThan',
  'lessThanInclusive',
  'minLength',
  'maxLength',
  'selectedCountEqual',
  'selectedCountNotEqual',
] as const;
export type PredicateOperator = (typeof PREDICATE_OPERATORS)[number];

/** Conjunction is the explicit `all` node only — no implicit AND/OR. */
export type Predicate =
  | { all: Predicate[] }
  | { op: PredicateOperator; value: string | number | boolean | Array<string | number> };

export type AnswerOperation = {
  id: string;
  kind: 'answer';
  /** registry key parts — resolution is fail-closed by name (§3.6) */
  family: string;
  version?: string;
  mode?: string;
  /** family-specific payload; the registry validates it when it drives (§3.6) */
  directive: Record<string, unknown>;
};

export type GateOperation = {
  id: string;
  kind: 'gate';
  gate: GateKind;
};

export type LocalOperation = AnswerOperation | GateOperation;

/**
 * What the evaluation payload must satisfy. `part_path` suffix-matches one
 * submitted path; `part_path_prefix` quantifies over a cluster —
 * `min_count` counts DISTINCT satisfied paths (R4-SF3: array entries could
 * satisfy a count with one duplicated blank).
 */
export type GradingExpectation =
  | { part_path: string; predicate: Predicate }
  | { part_path_prefix: string; predicate?: Predicate; min_count?: number };

export type CorrectPlanKind = 'navigation' | 'feedback' | 'none';

export type ScreenDefinition = {
  id: string;
  resource_id: number;
  role: ScreenRole;
  combine_feedback?: boolean;
  /** archive-derived plan kind of the enabled correct rules' actions —
   * `feedback` when any correct action shows feedback (planTransition
   * precedence), else `navigation`, else `none`. Pins the plan-dependent
   * driver-evidence classes to the ARCHIVE (gate-B0 r7 M3). */
  correct_plan?: CorrectPlanKind;
  /** ancestor chain for provenance, nearest first — non-manifest layer parents */
  layer_parents?: string[];
  operations?: LocalOperation[];
  expectations?: GradingExpectation[];
  /** declared cross-screen dependencies — manifest screen ids (§3.6) */
  dependencies?: string[];
  /** navigation screens: the in-widget button that drives the transition */
  action?: { kind: 'in_widget_button'; src_fragment: string };
};

export type ScenarioStep = {
  screen_ref: string;
  expected_verdict: ExpectedVerdict;
  /** refs into the screen definition's operations; omitted = all, in definition order */
  operation_refs?: string[];
};

export type ManifestExclusion = { screen: string; reason: string };

export type AdaptiveManifest = {
  screens: ScreenDefinition[];
  scenario: ScenarioStep[];
  /** off-route screens, explicitly classified — never silent (§3.8) */
  exclusions?: ManifestExclusion[];
  /**
   * The score a fully-correct run must land on. When declared, the oracle
   * sums every evaluation's wire-reported score over an ACCEPTED run and
   * refuses a mismatch — all-verdicts-true does not by itself prove the
   * grading pipeline pointed correctly.
   */
  expected_total_score?: number;
};

const fail = (msg: string): never => {
  throw new Error(`invalid adaptive manifest: ${msg}`);
};

const isNonEmptyString = (v: unknown): v is string => typeof v === 'string' && v.length > 0;

/** Per-operator argument-type table (§3.8) — validated by name, no coercion. */
type ArgKind = 'scalar' | 'string-or-list' | 'list' | 'number';
const OPERATOR_ARGS: Record<PredicateOperator, ArgKind> = {
  equal: 'scalar',
  notEqual: 'scalar',
  contains: 'string-or-list',
  notContains: 'string-or-list',
  containsAnyOf: 'list',
  notContainsAnyOf: 'list',
  containsOnly: 'list',
  greaterThan: 'number',
  greaterThanInclusive: 'number',
  lessThan: 'number',
  lessThanInclusive: 'number',
  minLength: 'number',
  maxLength: 'number',
  selectedCountEqual: 'number',
  selectedCountNotEqual: 'number',
};

function validatePredicate(raw: unknown, at: string): void {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    fail(`${at} is not a predicate object`);
  }
  const node = raw as Record<string, unknown>;
  if ('all' in node) {
    if (!Array.isArray(node.all) || node.all.length === 0) {
      fail(`${at}.all must be a non-empty predicate array`);
    }
    (node.all as unknown[]).forEach((child, i) => validatePredicate(child, `${at}.all[${i}]`));
    return;
  }
  const op = node.op as PredicateOperator;
  if (!PREDICATE_OPERATORS.includes(op)) {
    fail(`${at} has unknown operator "${String(node.op)}"`);
  }
  const value = node.value;
  // empty condition arguments are forbidden at validation, never silently passing
  const kind = OPERATOR_ARGS[op];
  const isEmptyish =
    value === undefined ||
    value === null ||
    value === '' ||
    (Array.isArray(value) && value.length === 0);
  if (isEmptyish) fail(`${at} (${op}) has an empty condition argument`);
  const typeOk =
    kind === 'number'
      ? typeof value === 'number' && !Number.isNaN(value)
      : kind === 'list'
        ? Array.isArray(value)
        : kind === 'string-or-list'
          ? typeof value === 'string' || Array.isArray(value)
          : ['string', 'number', 'boolean'].includes(typeof value) || Array.isArray(value);
  if (!typeOk) fail(`${at} (${op}) argument type does not match the operator's declared type`);
  if (Array.isArray(value)) {
    const elementsOk = value.every(
      (v) => typeof v === 'string' || (typeof v === 'number' && !Number.isNaN(v)),
    );
    if (!elementsOk) fail(`${at} (${op}) list elements must be strings or numbers`);
  }
}

function validateExpectation(raw: unknown, at: string): void {
  if (!raw || typeof raw !== 'object') fail(`${at} is not an expectation object`);
  const e = raw as Record<string, unknown>;
  if ('part_path' in e) {
    if (!isNonEmptyString(e.part_path)) fail(`${at}.part_path must be a non-empty string`);
    if (e.min_count !== undefined) fail(`${at}: min_count belongs to part_path_prefix only`);
    validatePredicate(e.predicate, `${at}.predicate`);
    return;
  }
  if (!isNonEmptyString(e.part_path_prefix)) {
    fail(`${at} needs part_path or a non-empty part_path_prefix`);
  }
  if (e.min_count !== undefined) {
    if (typeof e.min_count !== 'number' || !Number.isInteger(e.min_count) || e.min_count < 1) {
      fail(`${at}.min_count must be a positive integer`);
    }
  }
  // §6.3's presence-only scope is EMPTY under its resolved arm (a) — every
  // authored expectation must declare what it proves. The oracle stays total
  // over presence-only receipts; authoring one is refused here, by name.
  if (e.predicate === undefined) {
    fail(`${at} is presence-only (part_path_prefix without predicate) — outside §6.3's scope`);
  }
  validatePredicate(e.predicate, `${at}.predicate`);
}

/**
 * Build-time validation (§3.8): identity/role shape, operation-id and
 * operation-ref contracts, predicate AST by name and argument type, scenario
 * resolution. Archive completeness is the separate `validateRouteCoverage`
 * gate — scenario-only coverage is self-referential.
 */
export function validateAdaptiveManifest(raw: unknown): AdaptiveManifest {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    fail('manifest must be an object with screens and scenario');
  }
  const manifest = raw as Record<string, unknown>;
  if (!Array.isArray(manifest.screens) || manifest.screens.length === 0) {
    fail('screens must be a non-empty array');
  }
  if (!Array.isArray(manifest.scenario) || manifest.scenario.length === 0) {
    fail('scenario must be a non-empty array');
  }
  if (manifest.expected_total_score !== undefined) {
    const s = manifest.expected_total_score;
    if (typeof s !== 'number' || !Number.isFinite(s) || s < 0) {
      fail('expected_total_score must be a finite non-negative number');
    }
  }

  const screens = manifest.screens as Array<Record<string, unknown>>;
  const screenIds = new Set<string>();
  const operationIds = new Map<string, Set<string>>();

  screens.forEach((s, i) => {
    const at = `screens[${i}]`;
    if (!s || typeof s !== 'object' || Array.isArray(s)) fail(`${at} is not an object`);
    if (!isNonEmptyString(s.id)) fail(`${at}.id must be a non-empty string`);
    const id = s.id as string;
    if (screenIds.has(id)) fail(`duplicate screen id "${id}"`);
    screenIds.add(id);
    if (typeof s.resource_id !== 'number') fail(`${at} ("${id}").resource_id must be a number`);
    if (!['graded', 'content', 'navigation'].includes(s.role as string)) {
      fail(`${at} ("${id}").role must be graded|content|navigation`);
    }
    if (
      s.correct_plan !== undefined &&
      !['navigation', 'feedback', 'none'].includes(s.correct_plan as string)
    ) {
      fail(`${at} ("${id}").correct_plan must be navigation, feedback or none`);
    }
    // combine_feedback flips the footer's event-selection branch (§3.5) — a
    // truthy non-boolean must never coerce its way into planning
    if (s.combine_feedback !== undefined && typeof s.combine_feedback !== 'boolean') {
      fail(`${at} ("${id}").combine_feedback must be a boolean when present`);
    }

    const ids = new Set<string>();
    const operations = (s.operations ?? []) as Array<Record<string, unknown>>;
    if (!Array.isArray(operations)) fail(`${at} ("${id}").operations must be an array`);
    operations.forEach((op, j) => {
      const oat = `${at}.operations[${j}]`;
      if (!isNonEmptyString(op.id)) fail(`${oat}.id must be a non-empty string`);
      if (ids.has(op.id as string)) {
        fail(`screen "${id}" declares duplicate operation id "${String(op.id)}"`);
      }
      ids.add(op.id as string);
      if (op.kind === 'answer') {
        if (!isNonEmptyString(op.family)) fail(`${oat} (answer) must name a family`);
        // version and mode are registry-key components (§3.6) — a non-string
        // key part must fail the build, not step-4 registry resolution
        if (op.version !== undefined && !isNonEmptyString(op.version)) {
          fail(`${oat} (answer).version must be a non-empty string when present`);
        }
        if (op.mode !== undefined && !isNonEmptyString(op.mode)) {
          fail(`${oat} (answer).mode must be a non-empty string when present`);
        }
        if (!op.directive || typeof op.directive !== 'object') {
          fail(`${oat} (answer) must carry a directive object`);
        }
      } else if (op.kind === 'gate') {
        if (!['carousel_view', 'flashcard_flip_all', 'video_start'].includes(op.gate as string)) {
          fail(`${oat} (gate) has unknown gate "${String(op.gate)}"`);
        }
      } else {
        fail(`${oat}.kind must be answer|gate`);
      }
    });
    operationIds.set(id, ids);

    const expectations = (s.expectations ?? []) as unknown[];
    if (!Array.isArray(expectations)) fail(`${at} ("${id}").expectations must be an array`);
    expectations.forEach((e, j) => validateExpectation(e, `${at}.expectations[${j}]`));

    if (s.role === 'graded' && expectations.length === 0) {
      fail(`${at} ("${id}") is graded and must declare grading expectations`);
    }
    if (s.role === 'navigation') {
      const action = s.action as Record<string, unknown> | undefined;
      if (!action || action.kind !== 'in_widget_button' || !isNonEmptyString(action.src_fragment)) {
        fail(`${at} ("${id}") is navigation and must declare an in_widget_button action`);
      }
    } else if (s.action !== undefined) {
      fail(`${at} ("${id}") is ${String(s.role)} and must not declare an action`);
    }

    if (s.dependencies !== undefined) {
      if (!Array.isArray(s.dependencies) || !s.dependencies.every(isNonEmptyString)) {
        fail(`${at} ("${id}").dependencies must be screen-id strings`);
      }
    }
    if (s.layer_parents !== undefined) {
      if (!Array.isArray(s.layer_parents) || !s.layer_parents.every(isNonEmptyString)) {
        fail(`${at} ("${id}").layer_parents must be id strings`);
      }
    }
  });

  // dependencies must name manifest screens — offline bidirectional archive
  // validation (§3.6) builds on this structural check
  screens.forEach((s) => {
    for (const dep of (s.dependencies ?? []) as string[]) {
      if (!screenIds.has(dep)) {
        fail(
          `screen "${String(s.id)}" declares dependency "${dep}" which is not a manifest screen`,
        );
      }
      if (dep === s.id) fail(`screen "${String(s.id)}" cannot depend on itself`);
    }
  });

  const scenario = manifest.scenario as Array<Record<string, unknown>>;
  const routed = new Set<string>();
  scenario.forEach((step, i) => {
    const at = `scenario[${i}]`;
    if (!isNonEmptyString(step.screen_ref)) fail(`${at}.screen_ref must be a non-empty string`);
    const ref = step.screen_ref as string;
    if (!screenIds.has(ref)) fail(`${at} references undeclared screen "${ref}"`);
    if (routed.has(ref)) fail(`${at}: screen "${ref}" already has a scenario step`);
    routed.add(ref);
    if (!['correct', 'incorrect'].includes(step.expected_verdict as string)) {
      fail(`${at}.expected_verdict must be correct|incorrect`);
    }
    if (step.operation_refs !== undefined) {
      if (!Array.isArray(step.operation_refs) || !step.operation_refs.every(isNonEmptyString)) {
        fail(`${at}.operation_refs must be id strings`);
      }
      const available = operationIds.get(ref) as Set<string>;
      const seen = new Set<string>();
      for (const opRef of step.operation_refs as string[]) {
        if (!available.has(opRef)) {
          fail(`${at} references operation "${opRef}" not declared by screen "${ref}"`);
        }
        if (seen.has(opRef)) fail(`${at} references operation "${opRef}" twice`);
        seen.add(opRef);
      }
    }
  });

  const exclusions = (manifest.exclusions ?? []) as Array<Record<string, unknown>>;
  if (!Array.isArray(exclusions)) fail('exclusions must be an array');
  exclusions.forEach((x, i) => {
    if (!isNonEmptyString(x.screen)) fail(`exclusions[${i}].screen must be a screen id`);
    if (!screenIds.has(x.screen as string)) {
      fail(`exclusions[${i}] names undeclared screen "${String(x.screen)}"`);
    }
    if (routed.has(x.screen as string)) {
      fail(`exclusions[${i}]: screen "${String(x.screen)}" is on the route and excluded`);
    }
    if (!isNonEmptyString(x.reason)) fail(`exclusions[${i}] must state a reason`);
  });

  // every screen is routed or explicitly classified — never silent
  const excluded = new Set(exclusions.map((x) => x.screen as string));
  Array.from(screenIds).forEach((id) => {
    if (!routed.has(id) && !excluded.has(id)) {
      fail(`screen "${id}" is neither on the scenario route nor classified in exclusions`);
    }
  });

  return raw as AdaptiveManifest;
}

/**
 * Facts derived OFFLINE from the course archive — the inputs the build-time
 * proofs need (§3.6(b), §3.5 final step). The manifest can never self-
 * validate against itself; these come from the archive, or the proof is not
 * a proof.
 */
export type ArchiveFacts = {
  /** reachable screen inventory from the archive's transition graph */
  screen_ids: string[];
  /**
   * the page's AUTHORED total score (content.custom.totalScore). When the
   * archive declares it, the manifest's expected_total_score must exist and
   * equal it — the score anchor is the ingested content, never hand-typed.
   */
  total_score?: number;
  /** the archive-selected route's ENTRY screen — the scenario must start here */
  route_start_id: string;
  /**
   * per screen — TOTAL over the inventory: the archive's activity
   * resource_id. Identity's second half (§3.8): live imports remap resource
   * ids, so this offline gate is the only place the mapping is provable.
   */
  resource_ids: Record<string, number>;
  /**
   * the archive-proven last navigable entry: the screen whose `next` resolves
   * no successor (the deck ends the lesson exactly there, `deck.ts:361`)
   */
  last_navigable_id: string;
  /**
   * per screen: where the expected-correct rule's navigation RESOLVES —
   * the successor screen id, or `@end` when it terminates the lesson.
   * Derived offline from the archive rules + sequence; with the proven
   * start, every scenario EDGE from head through terminal is provable.
   */
  route_successors: Record<string, string>;
  /**
   * per screen — TOTAL over the inventory, empty array meaning "the
   * extractor PROVED no dependencies": the archive's effective dependency
   * set (`activitiesRequiredForEvaluation` plus what its rules reference —
   * the server infers exactly this, `evaluate.ex:448-453`). An absent key
   * is missing evidence, never an empty proof — the build fails closed.
   */
  effective_dependencies: Record<string, string[]>;
  /**
   * per screen — TOTAL over the inventory, empty array meaning "the
   * extractor PROVED no references": every prior-state part path the
   * expected-correct rule references; each must be covered by a grading
   * expectation (§3.6(b), bidirectional). Same fail-closed totality rule.
   */
  rule_prior_state_refs: Record<string, string[]>;
  /**
   * per screen — TOTAL over the inventory, explicit false included: the
   * archive's combineFeedback flag. The flag flips the footer-normative
   * planner branch on BOTH replay consumers (projection + expected driver
   * evidence), so a manifest that loses it must fail the build, not feed a
   * common-mode default into the comparison (gate-B0 r5 M2).
   */
  combine_feedback: Record<string, boolean>;
  /**
   * per screen — TOTAL over the inventory: the plan kind the enabled correct
   * rules' authored actions produce (`feedback` outranks `navigation`,
   * planTransition precedence). The expected driver-evidence inventory's
   * plan-dependent classes derive from THIS map, never from the captured
   * response — a common-mode journal/ledger plan substitution cannot shrink
   * the multiset (gate-B0 r7 M3).
   */
  correct_plan_kinds: Record<string, CorrectPlanKind>;
  /**
   * per screen — TOTAL over the inventory: any ENABLED rule carries an
   * `activationPoint` action of kind `feedback` — the server's LLM-feedback
   * trigger (`llm_feedback.ex` find_llm_feedback_prompt;
   * `attempt_controller.ex:753-768` attaches `llm_feedback` to the
   * response). Runtime llmFeedback OUTRANKS authored actions in
   * planTransition, so an LLM-capable screen's plan kind is NOT
   * archive-determined: the coverage gate fails closed on any true value
   * until an independent runtime reference pins the outcome (gate-B0 r8 M2).
   */
  llm_feedback_capable: Record<string, boolean>;
};

const coveredByExpectation = (ref: string, expectations: GradingExpectation[]): boolean =>
  expectations.some((e) =>
    'part_path' in e
      ? ref === e.part_path || ref.endsWith(e.part_path)
      : ref.includes(e.part_path_prefix),
  );

/**
 * Archive completeness + dependency proofs (§3.8, §3.6(b), §3.5):
 * 1. bijection — the reachable archive inventory maps 1:1 onto screen
 *    definitions (scenario-only coverage is self-referential — the
 *    historical 4-of-22 failure class would survive it);
 * 2. the scenario's last step is the archive-proven last navigable entry —
 *    the offline half of the oracle's navigate-off-sequence exception;
 * 3. declared cross-screen dependencies belong to the archive's effective
 *    dependency set (a mistaken manifest dependency cannot self-validate);
 * 4. every prior-state reference in the expected-correct rule is covered by
 *    a grading expectation — an underdeclared receipt fails the build, it
 *    cannot lean on the verdict for the rest.
 */
export function validateRouteCoverage(facts: ArchiveFacts, manifest: AdaptiveManifest): void {
  if (facts.total_score !== undefined) {
    if (manifest.expected_total_score === undefined) {
      fail(
        `the archive authors totalScore=${facts.total_score} but the manifest declares no expected_total_score`,
      );
    }
    if (manifest.expected_total_score !== facts.total_score) {
      fail(
        `manifest expected_total_score=${manifest.expected_total_score} contradicts the archive's authored totalScore=${facts.total_score}`,
      );
    }
  }
  const declared = new Set(manifest.screens.map((s) => s.id));
  const archive = new Set(facts.screen_ids);
  if (archive.size !== facts.screen_ids.length) {
    fail('archive inventory contains duplicate screen ids');
  }
  Array.from(archive).forEach((id) => {
    if (!declared.has(id)) fail(`archive screen "${id}" has no screen definition`);
  });
  Array.from(declared).forEach((id) => {
    if (!archive.has(id)) fail(`screen definition "${id}" does not exist in the archive inventory`);
  });

  if (!archive.has(facts.last_navigable_id)) {
    fail(`last navigable screen "${facts.last_navigable_id}" is not in the archive inventory`);
  }
  const lastStep = manifest.scenario[manifest.scenario.length - 1];
  if (lastStep.screen_ref !== facts.last_navigable_id) {
    fail(
      `scenario ends at "${lastStep.screen_ref}" but the archive proves ` +
        `"${facts.last_navigable_id}" is the last navigable entry`,
    );
  }

  // every scenario EDGE is archive-proven: step i's expected-correct
  // navigation resolves to step i+1's screen, and the last step's to @end —
  // a permuted middle can no longer pass on endpoints alone
  manifest.scenario.forEach((step, i) => {
    const successor = facts.route_successors[step.screen_ref];
    if (successor === undefined) {
      fail(`archive facts carry no route successor for scenario screen "${step.screen_ref}"`);
    }
    const expected =
      i === manifest.scenario.length - 1 ? '@end' : manifest.scenario[i + 1].screen_ref;
    if (successor !== expected) {
      fail(
        `scenario edge ${i}: the archive resolves "${step.screen_ref}" to "${successor}", ` +
          `the scenario declares "${expected}"`,
      );
    }
  });

  // the scenario is proven from HEAD through terminal: without the archive's
  // route start, a proper suffix of the selected route could classify the
  // omitted head as an exclusion and pass every remaining check
  if (!archive.has(facts.route_start_id)) {
    fail(`route start "${facts.route_start_id}" is not in the archive inventory`);
  }
  if (manifest.scenario[0].screen_ref !== facts.route_start_id) {
    fail(
      `scenario starts at "${manifest.scenario[0].screen_ref}" but the archive proves ` +
        `"${facts.route_start_id}" is the selected route's entry`,
    );
  }

  // per-screen fact maps are TOTAL over the inventory — an absent key is
  // missing evidence (fail closed), an extra key is a facts/inventory
  // mismatch; an explicit [] is the extractor's proof of "none"
  (
    [
      'effective_dependencies',
      'rule_prior_state_refs',
      'resource_ids',
      'combine_feedback',
      'correct_plan_kinds',
      'llm_feedback_capable',
    ] as const
  ).forEach((mapName) => {
    const map = facts[mapName];
    Array.from(archive).forEach((id) => {
      if (map[id] === undefined) {
        fail(`archive facts carry no ${mapName} entry for screen "${id}" — missing evidence`);
      }
    });
    Object.keys(map).forEach((id) => {
      if (!archive.has(id)) {
        fail(`archive facts ${mapName} names "${id}", which is not in the inventory`);
      }
    });
  });

  // identity's second half: every screen definition's resource_id must equal
  // the archive's — live imports remap ids, so only this gate can prove it
  for (const screen of manifest.screens) {
    if (screen.resource_id !== facts.resource_ids[screen.id]) {
      fail(
        `screen "${screen.id}" declares resource_id ${screen.resource_id}, the archive ` +
          `proves ${facts.resource_ids[screen.id]}`,
      );
    }
  }

  // combine_feedback is EXACT per screen — an absent manifest flag means
  // false and must match the archive's explicit false, so a dropped flag on
  // a combining screen fails here instead of defaulting both replay
  // consumers to the same wrong branch (gate-B0 r5 M2)
  for (const screen of manifest.screens) {
    if (!!screen.combine_feedback !== facts.combine_feedback[screen.id]) {
      fail(
        `screen "${screen.id}" declares combine_feedback ${!!screen.combine_feedback}, ` +
          `the archive proves ${facts.combine_feedback[screen.id]}`,
      );
    }
  }

  // correct_plan is EXACT per screen and REQUIRED once the facts carry it —
  // the plan-dependent driver-evidence classes derive from this manifest
  // field, so a missing or drifted value must fail the build (gate-B0 r7 M3)
  for (const screen of manifest.screens) {
    if (screen.correct_plan !== facts.correct_plan_kinds[screen.id]) {
      fail(
        `screen "${screen.id}" declares correct_plan ${String(screen.correct_plan)}, ` +
          `the archive proves ${facts.correct_plan_kinds[screen.id]}`,
      );
    }
  }

  // an LLM-capable screen's runtime plan kind is not archive-determined
  // (llmFeedback outranks authored actions in planTransition) — fail closed
  // until an independent runtime reference exists (gate-B0 r8 M2)
  for (const id of Object.keys(facts.llm_feedback_capable)) {
    if (facts.llm_feedback_capable[id]) {
      fail(
        `screen "${id}" carries an LLM feedback activation point — its plan kind is not ` +
          'archive-determined; the strict framework has no runtime reference for it yet',
      );
    }
  }

  for (const screen of manifest.screens) {
    const deps = screen.dependencies ?? [];
    const effective = facts.effective_dependencies[screen.id];
    for (const dep of deps) {
      if (!effective.includes(dep)) {
        fail(
          `screen "${screen.id}" declares dependency "${dep}" outside the archive's ` +
            'effective dependency set',
        );
      }
    }
    // the bidirectional half runs for EVERY screen — omitting `dependencies`
    // must not bypass it: an archive rule that reads another screen's state
    // demands both the declaration and a covering expectation
    const refs = facts.rule_prior_state_refs[screen.id];
    for (const ref of refs) {
      const owner = ref.includes('|') ? ref.slice(0, ref.indexOf('|')) : screen.id;
      if (owner !== screen.id && !deps.includes(owner)) {
        fail(
          `screen "${screen.id}" rule reads prior state of "${owner}" without declaring it ` +
            'as a dependency',
        );
      }
      // expectation completeness is UNCONDITIONAL (§3.6b): a same-screen rule
      // reference without a covering expectation leans on the verdict exactly
      // like a foreign one — the owner distinction governs only declaration
      if (!coveredByExpectation(ref, screen.expectations ?? [])) {
        fail(
          `screen "${screen.id}" rule references prior state "${ref}" with no covering ` +
            'grading expectation — an underdeclared receipt cannot lean on the verdict',
        );
      }
    }
  }
}

/** Refs omitted = every local operation exactly once, in DEFINITION order (§3.8). */
export function resolveOperations(screen: ScreenDefinition, step: ScenarioStep): LocalOperation[] {
  const operations = screen.operations ?? [];
  if (step.operation_refs === undefined) return [...operations];
  const wanted = new Set(step.operation_refs);
  // execution order is screen-definition order regardless of ref order
  return operations.filter((op) => wanted.has(op.id));
}

/* ------------------------------------------------------------------------ *
 * Predicate evaluation — matchers MIRROR the production operator modules
 * (`assets/src/adaptivity/operators/*.ts`, normative) and the utils/common
 * parsing they rely on. Divergent list-op truth conditions pinned by §3.8:
 * contains = every condition element present in the input; notContains = its
 * negation; containsAnyOf = intersection non-empty; notContainsAnyOf =
 * intersection empty; containsOnly = same elements with equal cardinality.
 * ------------------------------------------------------------------------ */

const isStringArrayLiteral = (s: unknown): boolean =>
  typeof s === 'string' && s.charAt(0) === '[' && s.charAt(s.length - 1) === ']';

/**
 * utils/common `parseNumString` port (`common.ts:156-167`): `Number` is only
 * the ELIGIBILITY check, `parseFloat` does the conversion — so `' '`
 * normalizes to NaN (Number(' ') is 0, parseFloat(' ') is NaN) and `'0x10'`
 * to 0, exactly as production does.
 */
const parseNumString = (item: unknown): unknown => {
  if (typeof item !== 'string') return item;
  if (!item.length) return item;
  if (!Number.isNaN(Number(item))) return parseFloat(item);
  return item.trim();
};

/**
 * An operator ERROR is where the production code would THROW. A pure matcher
 * cannot mirror a crash; it represents it as a typed fail-closed result —
 * `'error'` never satisfies a predicate, under EITHER polarity.
 */
type OpResult = boolean | 'error';

/**
 * utils/common `parseArray` port, branch for branch (`common.ts:84-144`):
 * native arrays map parseNumString; string literals JSON-parse or split
 * (one nesting level; elements trim unless whitespace-only); falsy → [];
 * plain strings split on commas; numbers wrap; anything else THROWS in
 * production → `'error'` here.
 */
function parseArrayStrict(val: unknown): unknown[] | 'error' {
  if (Array.isArray(val)) return val.map(parseNumString);
  if (isStringArrayLiteral(val)) {
    const s = val as string;
    try {
      const json: unknown = JSON.parse(s);
      if (Array.isArray(json)) return json;
    } catch {
      // fall through to manual parsing, as the product does
    }
    const inner = s.slice(1, -1);
    if (isStringArrayLiteral(inner)) {
      const innerEls = inner
        .replace(/\], \[/g, '],\n[')
        .replace(/\],\[/g, '],\n[')
        .split(/,\n/g);
      const nested: unknown[] = [];
      for (const el of innerEls) {
        const parsed = parseArrayStrict(el);
        if (parsed === 'error') return 'error';
        nested.push(parsed);
      }
      return nested;
    }
    const elements = inner.split(',').map(parseNumString);
    const arr = elements.length === 1 && elements[0] === '' ? [] : elements;
    return arr.map((el) => (typeof el !== 'string' ? el : /^\s+$/.test(el) ? el : el.trim()));
  }
  if (!val) return [];
  if (typeof val === 'string') return val.split(',').map(parseNumString);
  if (typeof val === 'number' && !Number.isNaN(val)) return [val];
  return 'error'; // production: throw new Error('not a valid array')
}

/** §3.8 selectedChoices normalization — OUR contract, not a production port. */
export function parseArrayLike(val: unknown): unknown[] {
  const strict = parseArrayStrict(val);
  return strict === 'error' ? [] : strict;
}

const looksLikeArray = (val: unknown): boolean => Array.isArray(val) || isStringArrayLiteral(val);

/**
 * utils/common `parseBoolean` port (`common.ts:68-74`) — including the `on`
 * spelling. Production calls `input.toString()`: a null input THROWS there,
 * so callers must map null to the typed operator error before reaching this.
 */
const parseBooleanMirror = (v: unknown): boolean =>
  v !== undefined &&
  (v === true ||
    v === 1 ||
    String(v).toLowerCase() === 'true' ||
    String(v).toLowerCase() === 'on' ||
    String(v).toLowerCase() === '1');

/**
 * equality.ts `isEqual` port, branch for branch (`equality.ts:11-76`). The
 * array branch fires ONLY on a native-array FACT (a string-encoded array
 * fact takes the scalar branches and generally refuses — production quirk,
 * preserved); a number condition wraps to `[n]`; both sides sort and compare
 * by toString, then by JSON.
 */
function equalOperator(input: unknown, condition: unknown): OpResult {
  if (condition === undefined || input === undefined) return false;
  const typeOfValue = typeof condition;
  const typeOfFactValue = typeof input;
  if (typeOfValue === 'number' && Number.isNaN(input as number)) return false;
  if (Array.isArray(input)) {
    const updatedFact = parseArrayStrict(input);
    if (updatedFact === 'error') return 'error';
    let toParse: unknown = condition;
    if (!Array.isArray(condition) && typeOfValue === 'number') toParse = `[${String(condition)}]`;
    const updatedValue = parseArrayStrict(toParse);
    if (updatedValue === 'error') return 'error';
    const compareValue = [...updatedValue].sort();
    const sortedFact = [...updatedFact].sort();
    if (String(compareValue) === String(sortedFact)) return true;
    return JSON.stringify(sortedFact) === JSON.stringify(compareValue);
  }
  const stringifiedValue = String(condition).toLowerCase();
  if (
    typeOfFactValue === 'boolean' &&
    (stringifiedValue === 'true' || stringifiedValue === 'false')
  ) {
    return stringifiedValue === 'true' ? input === true : input === false;
  }
  if (typeOfValue === 'boolean') {
    // production: factValue.toString() — a null fact THROWS (`equality.ts:59`)
    if (input === null) return 'error';
    return String(input).toLowerCase() === 'true' || (input as number) > 0
      ? condition === true
      : condition === false;
  }
  if (typeOfValue === 'string' && (condition === 'true' || condition === 'false')) {
    // production: parseBoolean(factValue) — null.toString() THROWS
    if (input === null) return 'error';
    return parseBooleanMirror(condition) === parseBooleanMirror(input);
  }
  if (typeOfValue === 'number') return parseFloat(String(input)) === condition;
  if (typeOfFactValue === 'number') return parseFloat(String(condition)) === input;
  if (typeOfValue === 'string' && typeOfFactValue === 'string') {
    return (condition as string).trim().toLowerCase() === (input as string).trim().toLowerCase();
  }
  return input === condition;
}

/**
 * contains.ts mirror: every condition element present in the input. The falsy
 * INPUT guard is the production `!inputValue` — `0`, `false` and `''` all
 * refuse (`contains.ts:4`) — and after the array branches the production
 * operator only accepts STRING inputs (`contains.ts:41-49`): a non-string
 * scalar never satisfies a text containment, it falls through to `false`.
 */
function containsOperator(input: unknown, condition: unknown): OpResult {
  if (!condition || !input) return false;
  if (looksLikeArray(condition)) {
    const conditionArr = parseArrayStrict(condition);
    if (conditionArr === 'error') return 'error';
    if (looksLikeArray(input)) {
      const inputArr = parseArrayStrict(input);
      if (inputArr === 'error') return 'error';
      return conditionArr.every((item) => inputArr.includes(item));
    }
    // production calls inputValue.toLocaleLowerCase() here — a non-string
    // scalar THROWS (`contains.ts:20-26`): typed operator error, fail-closed
    if (typeof input !== 'string') return 'error';
    return conditionArr.every((item) =>
      typeof item === 'string'
        ? input.toLowerCase().includes(item.toLowerCase())
        : input.includes(String(item)),
    );
  }
  if (looksLikeArray(input)) {
    const inputArr = parseArrayStrict(input);
    if (inputArr === 'error') return 'error';
    return inputArr.some((item) =>
      typeof item === 'string'
        ? item.toLowerCase().includes(String(condition).toLowerCase())
        : item === condition,
    );
  }
  // after the array branches production accepts STRING inputs only
  // (`contains.ts:41-49`) — a non-string scalar falls through to false
  if (typeof input !== 'string') return false;
  return input.toLowerCase().includes(String(condition).toLowerCase());
}

/**
 * contains.ts `containsAnyOf`: intersection non-empty. Non-array inputs use
 * the production coercing `isNaN` + `parseFloat` pair (`contains.ts:68-69`) —
 * `" "` parses to NaN and matches nothing, never to `0`.
 */
function containsAnyOfOperator(input: unknown, condition: unknown): OpResult {
  if (!condition || !input) return false;
  const conditionArr = parseArrayStrict(condition);
  if (conditionArr === 'error') return 'error';
  if (looksLikeArray(input)) {
    const inputArr = parseArrayStrict(input);
    if (inputArr === 'error') return 'error';
    return inputArr.some((item) => conditionArr.includes(item));
  }
  if (!isNaN(input as number)) return conditionArr.includes(parseFloat(String(input)));
  return conditionArr.some((v) => String(input).toLowerCase().includes(String(v).toLowerCase()));
}

/**
 * contains.ts `notContainsAnyOf` is NOT a negation of `containsAnyOf`
 * (`contains.ts:79-96`): it has its own falsy guard (empty input REFUSES —
 * an empty submission can never satisfy an exclusion expectation) and its
 * string branch is case-SENSITIVE, unlike the positive operator's.
 */
function notContainsAnyOfOperator(input: unknown, condition: unknown): OpResult {
  if (!condition || !input) return false;
  const conditionArr = parseArrayStrict(condition);
  if (conditionArr === 'error') return 'error';
  if (looksLikeArray(input)) {
    const inputArr = parseArrayStrict(input);
    if (inputArr === 'error') return 'error';
    return !inputArr.some((item) => conditionArr.includes(item));
  }
  if (!isNaN(input as number)) return !conditionArr.includes(parseFloat(String(input)));
  return !conditionArr.some((v) => String(input).includes(String(v)));
}

/** contains.ts `containsOnly`: same elements with equal cardinality. */
function containsOnlyOperator(input: unknown, condition: unknown): OpResult {
  if (!condition || !input) return false;
  if (Array.isArray(input) && input.length < 1) return false;
  const inputArr = parseArrayStrict(input);
  if (inputArr === 'error') return 'error';
  const conditionArr = parseArrayStrict(condition);
  if (conditionArr === 'error') return 'error';
  if (inputArr.length !== conditionArr.length) return false;
  return inputArr.every((item) => conditionArr.includes(item));
}

/**
 * equality.ts `notEqual` mirror (`equality.ts:155-170`): when either side is
 * a number and the input is undefined or NaN, the rule REFUSES (`false`) —
 * a missing or non-numeric fact never satisfies an inequality.
 */
function notEqualOperator(
  input: unknown,
  condition: string | number | boolean | Array<string | number>,
): OpResult {
  if (
    (typeof condition === 'number' || typeof input === 'number') &&
    (input === undefined ||
      condition === undefined ||
      Number.isNaN(input as number) ||
      Number.isNaN(condition as number))
  ) {
    return false;
  }
  const eq = equalOperator(input, condition);
  return eq === 'error' ? 'error' : !eq;
}

/**
 * A production operator that would THROW satisfies nothing — under either
 * polarity. Negating a crash into a passing predicate is exactly the
 * fail-open the mirror must never introduce.
 */
const failClosed = (r: OpResult): boolean => r === true;
const failClosedNegation = (r: OpResult): boolean => (r === 'error' ? false : !r);

/**
 * json-rules-engine default numeric comparison
 * (`engine-default-operators.js:34-48`): the VALIDATOR runs `parseFloat` on
 * the fact, but the comparison uses the RAW fact — `"5abc"` passes the
 * validator yet compares as NaN and refuses; `"5"` coerces and compares.
 */
const numberValidator = (v: unknown): boolean =>
  Number.parseFloat(v as string).toString() !== 'NaN';

/** text comparisons trim + case-fold; length operators use the normalized string */
const normalizeText = (v: unknown): string => String(v).trim();

export function evaluatePredicate(predicate: Predicate, rawInput: unknown): boolean {
  if ('all' in predicate) return predicate.all.every((p) => evaluatePredicate(p, rawInput));
  const { op, value } = predicate;
  switch (op) {
    case 'equal':
      return failClosed(equalOperator(rawInput, value));
    case 'notEqual':
      return failClosed(notEqualOperator(rawInput, value));
    case 'contains':
      return failClosed(containsOperator(rawInput, value));
    case 'notContains':
      // production notContains IS a raw negation (`contains.ts:52`) — but an
      // operator ERROR (production crash) stays fail-closed, never negated
      return failClosedNegation(containsOperator(rawInput, value));
    case 'containsAnyOf':
      return failClosed(containsAnyOfOperator(rawInput, value));
    case 'notContainsAnyOf':
      return failClosed(notContainsAnyOfOperator(rawInput, value));
    case 'containsOnly':
      return failClosed(containsOnlyOperator(rawInput, value));
    case 'greaterThan':
      return numberValidator(rawInput) && (rawInput as number) > (value as number);
    case 'greaterThanInclusive':
      return numberValidator(rawInput) && (rawInput as number) >= (value as number);
    case 'lessThan':
      return numberValidator(rawInput) && (rawInput as number) < (value as number);
    case 'lessThanInclusive':
      return numberValidator(rawInput) && (rawInput as number) <= (value as number);
    case 'minLength':
      return normalizeText(rawInput).length >= (value as number);
    case 'maxLength':
      return normalizeText(rawInput).length <= (value as number);
    case 'selectedCountEqual':
      return selectedCount(rawInput) === (value as number);
    case 'selectedCountNotEqual':
      return selectedCount(rawInput) !== (value as number);
  }
}

/**
 * `selectedChoices` normalization (§3.8): BOTH measured encodings —
 * stringified array `"[1,2,3]"` and native list — normalize to a number list
 * before counting; non-numeric entries never count as selections.
 */
export function selectedCount(rawInput: unknown): number {
  return parseArrayLike(rawInput).filter((v) => typeof v === 'number' && !Number.isNaN(v)).length;
}
