import fs from 'node:fs';
import path from 'node:path';
import type { ArchiveFacts, CorrectPlanKind, ScreenRole } from './AdaptiveManifest';

/**
 * Independent reader of the EXTRACTED COURSE ARCHIVE (B4-MAN/B4-BIJ/B4-PRED).
 * The offline extractor that authors the manifest and the archive-facts JSON is
 * the leg under judgment; this parser is the breaking leg, so it shares no
 * code, constant, helper or intermediate file with it — it reads the archive's
 * own resource JSON and derives everything again. Every absence is missing
 * evidence and throws; nothing defaults.
 */

export type RawPart = {
  id: string;
  type: string;
  src: string | null;
  /** authored part config, verbatim — read by the space derivations below */
  custom: Record<string, unknown>;
};

export type RawCondition = {
  fact: string;
  operator: string;
  value: unknown;
  /** CAPI variable type as authored (3 = array) — carried, never interpreted here */
  type?: number;
};

export type RawConditionGroup = { kind: 'all' | 'any'; children: RawConditionNode[] };
export type RawConditionNode = RawCondition | RawConditionGroup;

export const isConditionGroup = (node: RawConditionNode): node is RawConditionGroup =>
  (node as RawConditionGroup).kind === 'all' || (node as RawConditionGroup).kind === 'any';

export type RawAction = { type: string; target: string | null; kind: string | null };

export type RawRule = {
  id: string;
  name: string;
  correct: boolean;
  disabled: boolean;
  isDefault: boolean;
  conditions: RawConditionGroup;
  actions: RawAction[];
};

export type RawScreen = {
  id: string;
  name: string;
  index: number;
  resourceId: number;
  parts: RawPart[];
  rules: RawRule[];
  activitiesRequiredForEvaluation: string[];
  combineFeedback: boolean;
};

export type RawArchivePage = {
  resourceId: number;
  title: string;
  screens: RawScreen[];
  /** the page's authored total score (content.custom.totalScore), when declared */
  totalScore?: number;
};

const fail = (msg: string): never => {
  throw new Error(`raw archive: ${msg}`);
};

const isPlainObject = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === 'object' && !Array.isArray(v);

function readResource(dir: string, resourceId: number): Record<string, unknown> {
  const file = path.join(dir, `${resourceId}.json`);
  if (!fs.existsSync(file)) fail(`resource ${resourceId} is absent from "${dir}"`);
  let parsed: unknown;
  try {
    parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    return fail(`resource ${resourceId} is not parseable JSON: ${String(e)}`);
  }
  if (!isPlainObject(parsed)) return fail(`resource ${resourceId} is not a JSON object`);
  return parsed;
}

/** Adaptive pages are the `advancedDelivery` ones — the deck layouts (§3.8). */
export function findAdaptivePages(dir: string): Array<{ resourceId: number; title: string }> {
  if (!fs.existsSync(dir)) fail(`archive directory "${dir}" does not exist`);
  const found: Array<{ resourceId: number; title: string }> = [];
  fs.readdirSync(dir).forEach((entry) => {
    if (!/^\d+\.json$/.test(entry)) return;
    const resourceId = parseInt(entry.slice(0, entry.length - 5), 10);
    const doc = readResource(dir, resourceId);
    if (doc.type !== 'Page') return;
    const content = doc.content;
    if (!isPlainObject(content) || content.advancedDelivery !== true) return;
    found.push({ resourceId, title: String(doc.title ?? '') });
  });
  return found.sort((a, b) => a.resourceId - b.resourceId);
}

function readConditionNode(raw: unknown, at: string): RawConditionNode {
  if (!isPlainObject(raw)) return fail(`${at} is not a condition object`);
  const nested = 'all' in raw ? 'all' : 'any' in raw ? 'any' : null;
  if (nested) {
    const children = raw[nested];
    if (!Array.isArray(children)) return fail(`${at}.${nested} is not an array`);
    return {
      kind: nested,
      children: children.map((c, i) => readConditionNode(c, `${at}.${nested}[${i}]`)),
    };
  }
  if (typeof raw.fact !== 'string' || raw.fact.length === 0) {
    return fail(`${at} carries no fact reference`);
  }
  if (typeof raw.operator !== 'string' || raw.operator.length === 0) {
    return fail(`${at} carries no operator`);
  }
  return {
    fact: raw.fact,
    operator: raw.operator,
    value: raw.value,
    type: typeof raw.type === 'number' ? raw.type : undefined,
  };
}

function readRule(raw: unknown, at: string): RawRule {
  if (!isPlainObject(raw)) return fail(`${at} is not a rule object`);
  const conditions = raw.conditions;
  // W-M3: an archive whose rules carry no conditions block is not evidence of
  // an unconditional rule, it is a truncated archive — fail, never default
  if (!isPlainObject(conditions) || !('all' in conditions || 'any' in conditions)) {
    return fail(`${at} ("${String(raw.name)}") has no conditions block`);
  }
  const node = readConditionNode(conditions, `${at}.conditions`);
  if (!isConditionGroup(node)) return fail(`${at}.conditions is not a condition group`);
  const event = raw.event;
  const params = isPlainObject(event) ? event.params : undefined;
  const rawActions = isPlainObject(params) ? params.actions : undefined;
  if (!Array.isArray(rawActions)) return fail(`${at} ("${String(raw.name)}") declares no actions`);
  const actions: RawAction[] = rawActions.map((a, i) => {
    if (!isPlainObject(a) || typeof a.type !== 'string') {
      return fail(`${at}.actions[${i}] has no type`);
    }
    const aParams = isPlainObject(a.params) ? a.params : {};
    return {
      type: a.type,
      target: typeof aParams.target === 'string' ? aParams.target : null,
      kind: typeof aParams.kind === 'string' ? aParams.kind : null,
    };
  });
  if (typeof raw.correct !== 'boolean') return fail(`${at} has no boolean "correct" flag`);
  if (typeof raw.disabled !== 'boolean') return fail(`${at} has no boolean "disabled" flag`);
  return {
    id: String(raw.id ?? ''),
    name: String(raw.name ?? ''),
    correct: raw.correct,
    disabled: raw.disabled,
    isDefault: raw.default === true,
    conditions: node,
    actions,
  };
}

function readActivity(dir: string, resourceId: number, screenId: string): Omit<RawScreen, 'index'> {
  const doc = readResource(dir, resourceId);
  const content = doc.content;
  if (!isPlainObject(content)) return fail(`activity ${resourceId} has no content`);
  const partsLayout = content.partsLayout;
  if (!Array.isArray(partsLayout)) return fail(`activity ${resourceId} has no partsLayout`);
  const parts: RawPart[] = partsLayout.map((p, i) => {
    if (!isPlainObject(p) || typeof p.id !== 'string' || typeof p.type !== 'string') {
      return fail(`activity ${resourceId} partsLayout[${i}] has no id/type`);
    }
    const custom = isPlainObject(p.custom) ? p.custom : {};
    return {
      id: p.id,
      type: p.type,
      src: typeof custom.src === 'string' ? custom.src : null,
      custom,
    };
  });
  const authoring = content.authoring;
  if (!isPlainObject(authoring)) return fail(`activity ${resourceId} has no authoring block`);
  if (!Array.isArray(authoring.rules)) return fail(`activity ${resourceId} has no authoring.rules`);
  const rules = authoring.rules.map((r, i) => readRule(r, `activity ${resourceId} rules[${i}]`));
  const required = authoring.activitiesRequiredForEvaluation;
  if (!Array.isArray(required)) {
    return fail(`activity ${resourceId} has no activitiesRequiredForEvaluation`);
  }
  const custom = isPlainObject(content.custom) ? content.custom : {};
  // the flag flips the footer's event-selection branch — an absent flag is
  // missing evidence, never a silent false on both replay consumers
  if (typeof custom.combineFeedback !== 'boolean') {
    return fail(`activity ${resourceId} ("${screenId}") declares no combineFeedback boolean`);
  }
  return {
    id: screenId,
    name: '',
    resourceId,
    parts,
    rules,
    activitiesRequiredForEvaluation: required.map((r) => String(r)),
    combineFeedback: custom.combineFeedback,
  };
}

/**
 * The deck's screen sequence is the page model's activity-reference list
 * (`content.model[0].children`). Layer and question-bank entries change what
 * `next` resolves to (`deck.ts:337-360`) — this reader refuses them rather
 * than deriving a route it cannot prove.
 */
export function readArchivePage(dir: string, pageResourceId: number): RawArchivePage {
  const doc = readResource(dir, pageResourceId);
  const content = doc.content;
  if (!isPlainObject(content)) return fail(`page ${pageResourceId} has no content`);
  if (content.advancedDelivery !== true) {
    return fail(`page ${pageResourceId} is not an advancedDelivery (adaptive) page`);
  }
  const model = content.model;
  if (!Array.isArray(model) || model.length !== 1 || !isPlainObject(model[0])) {
    return fail(`page ${pageResourceId} does not carry exactly one deck group`);
  }
  const pageCustom = isPlainObject(content.custom) ? content.custom : {};
  const totalScore = pageCustom.totalScore;
  if (totalScore !== undefined && (typeof totalScore !== 'number' || !Number.isFinite(totalScore))) {
    return fail(`page ${pageResourceId} custom.totalScore is not a finite number`);
  }
  const children = (model[0] as Record<string, unknown>).children;
  if (!Array.isArray(children) || children.length === 0) {
    return fail(`page ${pageResourceId} deck group has no children`);
  }

  const seen: Record<string, boolean> = {};
  const screens: RawScreen[] = children.map((child, index) => {
    if (!isPlainObject(child))
      return fail(`page ${pageResourceId} child ${index} is not an object`);
    const custom = isPlainObject(child.custom) ? child.custom : {};
    if (custom.isLayer === true || custom.isBank === true || typeof custom.layerRef === 'string') {
      return fail(
        `screen ${index} ("${String(custom.sequenceId)}") is a layer/bank entry — ` +
          'the route derivation is only proven for flat sequences',
      );
    }
    if (typeof custom.sequenceId !== 'string' || custom.sequenceId.length === 0) {
      return fail(`page ${pageResourceId} child ${index} has no sequenceId`);
    }
    if (seen[custom.sequenceId]) return fail(`duplicate sequenceId "${custom.sequenceId}"`);
    seen[custom.sequenceId] = true;
    if (typeof child.activity_id !== 'number') {
      return fail(`screen "${custom.sequenceId}" has no numeric activity_id`);
    }
    const screen = readActivity(dir, child.activity_id, custom.sequenceId);
    return {
      ...screen,
      index,
      name: typeof custom.sequenceName === 'string' ? custom.sequenceName : '',
    };
  });

  return {
    resourceId: pageResourceId,
    title: String(doc.title ?? ''),
    screens,
    ...(totalScore !== undefined ? { totalScore: totalScore as number } : {}),
  };
}

export type McqSpec = { choiceCount: number; mode: 'radio' | 'checkboxes' };

/**
 * The graded input space of a janus-mcq part, derived from the ARCHIVE — the
 * option list length and the authored `multipleSelection` flag
 * (`MultipleChoiceQuestion.tsx:337-341` numbers options from 1). A caller-
 * supplied choice count could silently under-enumerate an "exhaustive" proof,
 * so it is never accepted; a non-boolean flag is refused rather than coerced.
 */
export function mcqPartSpec(screen: RawScreen, partId: string): McqSpec {
  const part = screen.parts.filter((p) => p.id === partId)[0];
  if (!part) fail(`screen "${screen.id}" renders no part "${partId}"`);
  if ((part as RawPart).type !== 'janus-mcq') {
    fail(
      `part "${partId}" on screen "${screen.id}" is a ${(part as RawPart).type}, not a janus-mcq`,
    );
  }
  const items = (part as RawPart).custom.mcqItems;
  if (!Array.isArray(items) || items.length === 0) {
    fail(`part "${partId}" on screen "${screen.id}" declares no mcqItems`);
  }
  const multiple = (part as RawPart).custom.multipleSelection;
  if (multiple !== undefined && multiple !== null && typeof multiple !== 'boolean') {
    fail(`part "${partId}" on screen "${screen.id}" has a non-boolean multipleSelection`);
  }
  return {
    choiceCount: (items as unknown[]).length,
    mode: multiple === true ? 'checkboxes' : 'radio',
  };
}

export const enabledRules = (screen: RawScreen): RawRule[] =>
  screen.rules.filter((r) => !r.disabled);

export const enabledCorrectRules = (screen: RawScreen): RawRule[] =>
  screen.rules.filter((r) => !r.disabled && r.correct);

/** Every fact a condition tree reads, in first-seen order. */
export function referencedFacts(nodes: RawConditionNode[]): string[] {
  const out: string[] = [];
  const visit = (node: RawConditionNode) => {
    if (isConditionGroup(node)) {
      node.children.forEach(visit);
      return;
    }
    if (out.indexOf(node.fact) === -1) out.push(node.fact);
  };
  nodes.forEach(visit);
  return out;
}

const screenById = (page: RawArchivePage, id: string): RawScreen | undefined =>
  page.screens.filter((s) => s.id === id)[0];

/**
 * `next` is the following sequence entry, and running off the end ENDS the
 * lesson (`deck.ts:326-366`); any other target names a sequence id directly.
 * A screen whose enabled correct rules disagree on the target has no
 * answer-independent successor — that is a refusal, not a guess.
 */
export function routeSuccessors(page: RawArchivePage): Record<string, string> {
  const out: Record<string, string> = {};
  page.screens.forEach((screen) => {
    const targets: string[] = [];
    enabledCorrectRules(screen).forEach((rule) => {
      rule.actions.forEach((action) => {
        if (action.type !== 'navigation') return;
        if (!action.target) fail(`screen "${screen.id}" has a navigation action with no target`);
        if (targets.indexOf(action.target as string) === -1) targets.push(action.target as string);
      });
    });
    if (targets.length === 0) {
      fail(`screen "${screen.id}" has no correct-rule navigation — no route successor is provable`);
    }
    if (targets.length > 1) {
      fail(
        `screen "${screen.id}" correct rules navigate to ${targets.length} different targets ` +
          `(${targets.join(', ')}) — the successor is answer-dependent`,
      );
    }
    const target = targets[0];
    if (target === 'next') {
      const next = page.screens.filter((s) => s.index === screen.index + 1)[0];
      out[screen.id] = next ? next.id : '@end';
      return;
    }
    if (!screenById(page, target)) {
      fail(`screen "${screen.id}" navigates to "${target}", which is not in the sequence`);
    }
    out[screen.id] = target;
  });
  return out;
}

/** The screen whose `next` resolves no successor — the deck ends exactly there. */
export function lastNavigableScreenId(page: RawArchivePage): string {
  const successors = routeSuccessors(page);
  const terminal = Object.keys(successors).filter((id) => successors[id] === '@end');
  if (terminal.length !== 1) {
    return fail(`the archive proves ${terminal.length} terminal screens, expected exactly one`);
  }
  return terminal[0];
}

/**
 * Plan kind of the enabled correct rules' authored actions — `feedback`
 * outranks `navigation` (planTransition precedence). With `combineFeedback`
 * false only the FIRST matched correct event drives actions
 * (`checkResults.ts:31-35`), so a screen whose correct rules disagree on plan
 * kind has no answer-independent plan and is refused.
 */
export function correctPlanKind(screen: RawScreen): CorrectPlanKind {
  const rules = enabledCorrectRules(screen);
  if (rules.length === 0) return 'none';
  const kinds = rules.map((rule) => {
    if (rule.actions.some((a) => a.type === 'feedback')) return 'feedback' as CorrectPlanKind;
    if (rule.actions.some((a) => a.type === 'navigation')) return 'navigation' as CorrectPlanKind;
    return 'none' as CorrectPlanKind;
  });
  const distinct = kinds.filter((k, i) => kinds.indexOf(k) === i);
  if (distinct.length > 1) {
    return fail(
      `screen "${screen.id}" correct rules produce ${distinct.join('/')} plans — the plan kind ` +
        'is answer-dependent and not archive-determined',
    );
  }
  return distinct[0];
}

/** Sequence references inside a fact key: `<sequenceId>|stage.Part.key`. */
const sequenceRefOf = (fact: string): string | null =>
  fact.indexOf('|stage.') === -1 ? null : fact.slice(0, fact.indexOf('|'));

/**
 * Prior state lives under `stage.` — optionally owned by another sequence.
 * `session.*` and `variables.*` facts are lesson scope, not part paths, and no
 * grading expectation can cover them (§3.6(b) quantifies over part paths).
 */
const isPartStatePath = (fact: string): boolean => {
  const local = fact.indexOf('|') === -1 ? fact : fact.slice(fact.indexOf('|') + 1);
  return local.indexOf('stage.') === 0;
};

/**
 * Navigation screens drive the deck through an in-widget button; the deck never
 * asserts their verdict (§3.5), so their correct rules are not
 * grading-expectation material (gate-B0 r3 M1, shadow-gate-evidence.md:117).
 * BOTH measured shapes count (§3.3): LotE's Cover is a CAPI buttonwidget, while
 * d-orbitals' Title and greenhouse's Welcome Screen are janus-navigation-button
 * parts. A navigation screen may still carry a stage-conditioned correct rule,
 * as LotE's Cover does — the part, not the rule, decides the role.
 */
const isNavigationScreen = (screen: RawScreen): boolean =>
  screen.parts.some(
    (p) =>
      p.type === 'janus-navigation-button' ||
      (p.src ?? '').indexOf('/spr-widget-buttonwidget/') !== -1,
  );

/**
 * Role, derived from the ARCHIVE alone (round-2 disposition): a navigation part
 * makes the screen navigation; otherwise an enabled correct rule conditioned on
 * part state makes it graded; otherwise content. Role is the switch that arms
 * the oracle's receipt/verdict/payload checks (`AdaptiveOracle.ts` enters them
 * for `graded` only), so a manifest that mislabels a graded screen would
 * silently disarm them — it is corroborated here, never trusted.
 */
export function deriveScreenRole(screen: RawScreen): ScreenRole {
  if (isNavigationScreen(screen)) return 'navigation';
  const graded = enabledCorrectRules(screen).some((rule) =>
    referencedFacts([rule.conditions]).some(isPartStatePath),
  );
  return graded ? 'graded' : 'content';
}

/**
 * The server's own effective dependency set: `activitiesRequiredForEvaluation`
 * plus every sequence a rule condition reads (`evaluate.ex:448-453`).
 */
export function effectiveDependencies(screen: RawScreen): string[] {
  const out = screen.activitiesRequiredForEvaluation.slice();
  referencedFacts(enabledRules(screen).map((r) => r.conditions)).forEach((fact) => {
    const ref = sequenceRefOf(fact);
    if (ref && out.indexOf(ref) === -1) out.push(ref);
  });
  return out;
}

/** Runtime llmFeedback outranks authored actions, so this fails the build closed. */
export const llmFeedbackCapable = (screen: RawScreen): boolean =>
  enabledRules(screen).some((r) =>
    r.actions.some((a) => a.type === 'activationPoint' && a.kind === 'feedback'),
  );

/**
 * The archive facts the committed `validateRouteCoverage` gate consumes,
 * derived HERE from the raw archive — the same gate, run against an input the
 * extractor did not produce (B4-BIJ).
 */
export function deriveArchiveFacts(page: RawArchivePage): ArchiveFacts {
  const successors = routeSuccessors(page);
  const resourceIds: Record<string, number> = {};
  const dependencies: Record<string, string[]> = {};
  const priorStateRefs: Record<string, string[]> = {};
  const combine: Record<string, boolean> = {};
  const planKinds: Record<string, CorrectPlanKind> = {};
  const llm: Record<string, boolean> = {};
  page.screens.forEach((screen) => {
    resourceIds[screen.id] = screen.resourceId;
    dependencies[screen.id] = effectiveDependencies(screen);
    priorStateRefs[screen.id] = isNavigationScreen(screen)
      ? []
      : referencedFacts(enabledCorrectRules(screen).map((r) => r.conditions)).filter(
          isPartStatePath,
        );
    combine[screen.id] = screen.combineFeedback;
    planKinds[screen.id] = correctPlanKind(screen);
    llm[screen.id] = llmFeedbackCapable(screen);
  });
  return {
    screen_ids: page.screens.map((s) => s.id),
    route_start_id: page.screens[0].id,
    ...(page.totalScore !== undefined ? { total_score: page.totalScore } : {}),
    resource_ids: resourceIds,
    last_navigable_id: lastNavigableScreenId(page),
    route_successors: successors,
    effective_dependencies: dependencies,
    rule_prior_state_refs: priorStateRefs,
    combine_feedback: combine,
    correct_plan_kinds: planKinds,
    llm_feedback_capable: llm,
  };
}
