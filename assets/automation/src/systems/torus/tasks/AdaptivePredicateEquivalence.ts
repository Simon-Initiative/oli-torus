import { Engine, RuleProperties } from 'json-rules-engine';
import { CapiVariableTypes, coerceCapiValue, getCapiType } from '@product/adaptivity/capi';
import containsOperators from '@product/adaptivity/operators/contains';
import equalityOperators from '@product/adaptivity/operators/equality';
import type { GradingExpectation } from './AdaptiveManifest';
import { evaluatePredicate } from './AdaptiveManifest';
import {
  RawConditionNode,
  RawRule,
  RawScreen,
  enabledRules,
  isConditionGroup,
  mcqPartSpec,
  referencedFacts,
} from './AdaptiveArchiveReader';

/**
 * Exhaustive predicate equivalence (B4-PRED): over a screen's whole finite
 * graded input space, the archive's own rule chain and the manifest's declared
 * grading predicate must return the same verdict on EVERY state.
 *
 * The archive leg runs the PRODUCT's operator modules
 * (`assets/src/adaptivity/operators/{contains,equality}.ts`) inside the
 * PRODUCT's rules engine (`json-rules-engine`, same package and version), so
 * it re-derives no truth condition; the manifest leg runs the committed mirror
 * `evaluatePredicate`. The two legs therefore share nothing, and a mirror that
 * drifted from §3.8's normative modules shows up here as a disagreement
 * instead of cancelling out.
 *
 * BOUND: the product's `check()` also runs a janus-script preprocessing pass
 * over condition values (`rules-engine.ts:119-224`, expression evaluation and
 * array coercion). This checker does NOT reproduce it — it REFUSES any
 * condition whose value could be affected by it, so an expression-bearing rule
 * can never be silently mis-evaluated.
 */

type OperatorFn = (factValue: unknown, conditionValue: unknown) => boolean;

/** json-rules-engine defaults the product keeps (`engine-default-operators.js`). */
const ENGINE_DEFAULT_OPERATORS = [
  'equal',
  'notEqual',
  'in',
  'notIn',
  'contains',
  'doesNotContain',
  'lessThan',
  'lessThanInclusive',
  'greaterThan',
  'greaterThanInclusive',
];

const moduleOperators = (): Record<string, OperatorFn> => {
  const table: Record<string, OperatorFn> = {};
  const merge = (m: Record<string, OperatorFn>) => {
    Object.keys(m).forEach((name) => {
      table[name] = m[name];
    });
  };
  merge(containsOperators as unknown as Record<string, OperatorFn>);
  merge(equalityOperators as unknown as Record<string, OperatorFn>);
  return table;
};

/**
 * `range` and `math` are deliberately NOT wired: their truth conditions have
 * no v2 operator and no LotE occurrence, so a rule that used one must fail
 * loudly here rather than resolve to a json-rules-engine default of the same
 * name.
 */
const supportedOperators = (): string[] => {
  const names = Object.keys(moduleOperators());
  ENGINE_DEFAULT_OPERATORS.forEach((n) => {
    if (names.indexOf(n) === -1) names.push(n);
  });
  return names;
};

const fail = (msg: string): never => {
  throw new Error(`predicate equivalence: ${msg}`);
};

/** Mirrors `rulesEngineFactory` (`rules-engine.ts:48-56`) — module operators on top of the defaults. */
function buildEngine(): Engine {
  const engine = new Engine([], { allowUndefinedFacts: true });
  const table = moduleOperators();
  Object.keys(table).forEach((name) => engine.addOperator(name, table[name]));
  return engine;
}

const looksBracketed = (v: string): boolean =>
  v.charAt(0) === '[' && v.charAt(v.length - 1) === ']';

function assertPreprocessingFree(rule: RawRule, node: RawConditionNode): void {
  if (isConditionGroup(node)) {
    node.children.forEach((child) => assertPreprocessingFree(rule, child));
    return;
  }
  if (supportedOperators().indexOf(node.operator) === -1) {
    fail(`rule "${rule.name}" uses operator "${node.operator}", which this checker does not wire`);
  }
  const values = Array.isArray(node.value) ? node.value : [node.value];
  values.forEach((v) => {
    if (typeof v === 'string' && v.indexOf('{') !== -1) {
      fail(
        `rule "${rule.name}" condition on "${node.fact}" carries a janus-script expression — ` +
          'its value is not statically known and cannot be enumerated',
      );
    }
  });
  // `processRules` wraps a bare string in brackets for ARRAY-typed conditions
  // (`rules-engine.ts:192-199`); refuse rather than reproduce the coercion
  if (node.type === 3 && typeof node.value === 'string' && !looksBracketed(node.value)) {
    fail(
      `rule "${rule.name}" condition on "${node.fact}" is an unwrapped array literal — ` +
        'the product coerces it during preprocessing, which this checker does not run',
    );
  }
}

function toEngineConditions(node: RawConditionNode): Record<string, unknown> {
  if (isConditionGroup(node)) {
    const children = node.children.map(toEngineConditions);
    return node.kind === 'all' ? { all: children } : { any: children };
  }
  return { fact: node.fact, operator: node.operator, value: node.value };
}

const BUILTIN_DEFAULT_WRONG = 'builtin.defaultWrong';

type FoldedEvent = { type: string; order: number; correct: boolean; isDefault: boolean };

export type ArchiveVerdict = { correct: boolean; results: FoldedEvent[] };

/**
 * The product's own verdict fold (`rules-engine.ts:486-530`): every MATCHED
 * enabled rule contributes, the default-wrong event is removed first, and the
 * screen is correct when ANY remaining matched event is correct — it is a
 * disjunction over the enabled correct rules, not a first-match decision.
 */
export async function archiveVerdict(
  rules: RawRule[],
  facts: Record<string, unknown>,
): Promise<ArchiveVerdict> {
  const enabled = rules.filter((r) => !r.disabled);
  const ordered: Array<{
    key: string;
    correct: boolean;
    isDefault: boolean;
    rule: RawRule | null;
  }> = enabled.map((rule) => ({
    key: `${rule.id}::${rule.name}`,
    correct: rule.correct,
    isDefault: rule.isDefault,
    rule,
  }));
  if (ordered.length === 0 || !ordered.some((r) => r.isDefault && !r.correct)) {
    ordered.push({ key: BUILTIN_DEFAULT_WRONG, correct: false, isDefault: true, rule: null });
  }

  const engine = buildEngine();
  ordered.forEach((entry, index) => {
    if (entry.rule) assertPreprocessingFree(entry.rule, entry.rule.conditions);
    const properties: RuleProperties = {
      priority: index + 1,
      conditions: (entry.rule
        ? toEngineConditions(entry.rule.conditions)
        : { all: [] }) as RuleProperties['conditions'],
      event: {
        type: entry.key,
        params: { order: index + 1, correct: entry.correct, default: entry.isDefault },
      },
    };
    engine.addRule(properties);
  });

  const outcome = await engine.run(facts);
  const successEvents: FoldedEvent[] = outcome.events
    .map((e) => ({
      type: String(e.type),
      order: Number((e.params as Record<string, unknown>).order),
      correct: (e.params as Record<string, unknown>).correct === true,
      isDefault: (e.params as Record<string, unknown>).default === true,
    }))
    .sort((a, b) => a.order - b.order);

  const defaultWrong = successEvents.filter((e) => e.isDefault && !e.correct)[0];
  let results = successEvents.filter((e) => e !== defaultWrong);
  const correct = results.length > 0 && results.some((e) => e.correct);
  results = results.filter((e) => (correct ? e.correct : !e.correct));
  if (results.length === 0 && defaultWrong) results = [defaultWrong];
  return { correct, results };
}

/**
 * `check()` never hands the engine the raw submitted value: `evalAssignScript`
 * assigns it into the script environment first, and the CAPI type inference
 * turns a bracketed string into a real array before `env.toObj()` supplies
 * facts (`rules-engine.ts:483,496`; `capi.ts:43,101`). Reproducing that step
 * with the PRODUCT's own inference and coercion is what makes the stringified
 * leg prove the measured input path instead of a representation the engine
 * never sees. `shouldConvertNumbers` mirrors the numeric MCQ payload.
 */
export function engineFactOf(submitted: unknown): unknown {
  const capiType = getCapiType(submitted);
  if (capiType === CapiVariableTypes.ARRAY || capiType === CapiVariableTypes.ARRAY_POINT) {
    return coerceCapiValue(submitted, capiType, null, true);
  }
  return submitted;
}

const engineFacts = (facts: Record<string, unknown>): Record<string, unknown> => {
  const out: Record<string, unknown> = {};
  Object.keys(facts).forEach((key) => {
    out[key] = engineFactOf(facts[key]);
  });
  return out;
};

/**
 * `facts` are the WIRE representation the oracle's matcher sees; `engine` is
 * what the product's preprocessing turns them into before the rule chain runs.
 * Both encodings of one selection must produce the SAME engine fact — that
 * equality is asserted, not assumed.
 */
export type EnumeratedState = { label: string; facts: Record<string, unknown> };

/**
 * The janus-mcq selection space as the delivery component publishes it
 * (`MultipleChoiceQuestion.tsx:307-311, 522-539`): 1-based option values,
 * `selectedChoices` sorted ascending, `numberOfSelectedChoices` its length.
 * `selectedChoice` is emitted for single-selection only — in multi-select the
 * component publishes -1 on init and 0 after a full deselect
 * (`:526` vs `:568`), so no single value is provable and a rule reading it
 * must fail the referenced-fact check instead of silently taking one.
 *
 * The option count and selection mode come from the ARCHIVE, never a caller:
 * an under-declared count would shrink an "exhaustive" enumeration silently.
 */
/** NaN defeats every `>` comparison and Infinity permits any allocation — both are refused. */
function requireCap(maxStates: number): number {
  if (!Number.isInteger(maxStates) || maxStates < 1) {
    fail(`state cap must be a finite positive integer, got ${String(maxStates)}`);
  }
  return maxStates;
}

export function mcqStatesFromArchive(
  screen: RawScreen,
  partId: string,
  rawMaxStates: number = DEFAULT_MAX_STATES,
): EnumeratedState[] {
  const maxStates = requireCap(rawMaxStates);
  const spec = mcqPartSpec(screen, partId);
  // the cap is checked from the archive-declared COUNT, before allocation: a
  // 25-choice part would otherwise exhaust memory building the very power set
  // the cap exists to refuse
  const projected = spec.mode === 'radio' ? spec.choiceCount + 1 : Math.pow(2, spec.choiceCount);
  if (projected * ENCODINGS_PER_SELECTION > maxStates) {
    fail(
      `part "${partId}" on screen "${screen.id}" declares ${spec.choiceCount} choices — ` +
        `${projected * ENCODINGS_PER_SELECTION} states, above the ${maxStates} cap; the ` +
        'equivalence proof would not be exhaustive and is refused before enumeration',
    );
  }
  return mcqStates(partId, spec.choiceCount, spec.mode);
}

function mcqStates(
  partId: string,
  choiceCount: number,
  mode: 'radio' | 'checkboxes',
): EnumeratedState[] {
  if (!Number.isInteger(choiceCount) || choiceCount < 1) {
    fail(`mcq part "${partId}" declares ${choiceCount} choices`);
  }
  const prefix = `stage.${partId}.`;
  // §3.8 fixes selectedChoices normalization over BOTH measured encodings —
  // native list and stringified array. The v2 matcher must hold on each, and
  // the product operators branch on representation (`looksLikeAnArray`), so a
  // proof over one encoding leaves the other half of the contract unproven.
  const build = (selected: number[], encoding: 'native' | 'stringified'): EnumeratedState => {
    const facts: Record<string, unknown> = {};
    facts[`${prefix}selectedChoices`] =
      encoding === 'native' ? selected : `[${selected.join(',')}]`;
    facts[`${prefix}numberOfSelectedChoices`] = selected.length;
    if (mode === 'radio') {
      facts[`${prefix}selectedChoice`] = selected.length ? selected[0] : -1;
    }
    return { label: `selected=[${selected.join(',')}] (${encoding})`, facts };
  };
  const both = (selected: number[]): EnumeratedState[] => [
    build(selected, 'native'),
    build(selected, 'stringified'),
  ];
  if (mode === 'radio') {
    const states = both([]);
    for (let choice = 1; choice <= choiceCount; choice += 1) {
      both([choice]).forEach((s) => states.push(s));
    }
    return states;
  }
  const states: EnumeratedState[] = [];
  const total = Math.pow(2, choiceCount);
  for (let mask = 0; mask < total; mask += 1) {
    const selected: number[] = [];
    for (let bit = 0; bit < choiceCount; bit += 1) {
      if (Math.floor(mask / Math.pow(2, bit)) % 2 === 1) selected.push(bit + 1);
    }
    both(selected).forEach((s) => states.push(s));
  }
  return states;
}

/**
 * Only exact `part_path` expectations are provable — a prefix or presence-only
 * expectation states no truth condition, so it is refused rather than counted
 * as agreement (§6.3 arm (b) is a DECLARED reduction, never an equivalence).
 * The path match is EXACT here, not the coverage gate's suffix match: an
 * expectation that named a shorter suffix would be comparing against a fact
 * the enumeration never assigned.
 */
function exactPathExpectations(
  expectations: GradingExpectation[],
  state: EnumeratedState,
  screenId: string,
): Array<{ part_path: string; predicate: Parameters<typeof evaluatePredicate>[0] }> {
  return expectations.map((expectation) => {
    if (!('part_path' in expectation)) {
      return fail(
        `screen "${screenId}" declares a part_path_prefix expectation — a presence-only or ` +
          'prefix expectation carries no truth condition and cannot be proven equivalent',
      );
    }
    if (!(expectation.part_path in state.facts)) {
      return fail(
        `screen "${screenId}" expectation reads "${expectation.part_path}", which the ` +
          'enumerated state space does not produce',
      );
    }
    return expectation;
  });
}

export type EquivalenceReport = {
  screenId: string;
  states: number;
  correctStates: number;
  incorrectStates: number;
};

export type EquivalenceInput = {
  screen: RawScreen;
  expectations: GradingExpectation[];
  states: EnumeratedState[];
  /** enumeration is exhaustive or it is nothing — an oversized space FAILS */
  maxStates?: number;
  /** a space on which the archive verdict is constant proves nothing */
  requireDiscriminating?: boolean;
};

const DEFAULT_MAX_STATES = 4096;

/** every selection is enumerated under both §3.8 encodings */
const ENCODINGS_PER_SELECTION = 2;

/**
 * Throws naming the first disagreeing state. Never skips: an oversized space,
 * an unproduced referenced fact, an unwired operator, or a state-mutating rule
 * all fail loudly.
 */
export async function assertPredicateEquivalence(
  input: EquivalenceInput,
): Promise<EquivalenceReport> {
  const { screen, expectations, states } = input;
  const cap = requireCap(input.maxStates ?? DEFAULT_MAX_STATES);
  if (states.length === 0) fail(`screen "${screen.id}" has an empty state space`);
  if (states.length > cap) {
    fail(
      `screen "${screen.id}" enumerates ${states.length} states, above the ${cap} cap — ` +
        'the equivalence proof is not exhaustive and is refused',
    );
  }
  if (expectations.length === 0) {
    fail(`screen "${screen.id}" declares no grading expectations to compare`);
  }

  const rules = enabledRules(screen);
  const facts = referencedFacts(rules.map((r) => r.conditions));
  facts.forEach((fact) => {
    if (!(fact in states[0].facts)) {
      fail(
        `screen "${screen.id}" rules read "${fact}", which the enumerated state space does not ` +
          'produce — the enumeration would not be exhaustive over the graded input',
      );
    }
  });
  // a rule that mutates a fact the rules read makes the verdict depend on how
  // many evaluations preceded it — outside a single-evaluation equivalence
  rules.forEach((rule) => {
    rule.actions.forEach((action) => {
      if (action.type === 'mutateState' && action.target && facts.indexOf(action.target) !== -1) {
        fail(
          `screen "${screen.id}" rule "${rule.name}" mutates "${action.target}", which its own ` +
            'conditions read — the verdict is not evaluation-independent',
        );
      }
    });
  });

  // shape and fact availability are settled BEFORE any evaluation, so a
  // short-circuiting conjunction can never hide an unprovable expectation
  const declaredExpectations = exactPathExpectations(expectations, states[0], screen.id);

  // both encodings of a selection must preprocess to the SAME engine fact —
  // otherwise the "second encoding" leg is not the same input at all
  const byLabel: Record<string, string> = {};
  states.forEach((state) => {
    const selection = state.label.replace(/ \(.*\)$/, '');
    const fingerprint = JSON.stringify(engineFacts(state.facts));
    if (byLabel[selection] === undefined) {
      byLabel[selection] = fingerprint;
      return;
    }
    if (byLabel[selection] !== fingerprint) {
      fail(
        `screen "${screen.id}" selection ${selection}: the enumerated encodings preprocess to ` +
          'different engine facts, so they are not the same input under judgment',
      );
    }
  });

  let correctStates = 0;
  for (let i = 0; i < states.length; i += 1) {
    const state = states[i];
    // archive leg runs on the PREPROCESSED fact (what the engine receives);
    // the declared leg below runs on the raw wire value (what the oracle sees)
    const archive = await archiveVerdict(screen.rules, engineFacts(state.facts));
    const declared = declaredExpectations.every((e) =>
      evaluatePredicate(e.predicate, state.facts[e.part_path]),
    );
    if (archive.correct !== declared) {
      fail(
        `screen "${screen.id}" state ${state.label}: the archive rule chain says ` +
          `${archive.correct ? 'CORRECT' : 'INCORRECT'} and the declared predicate says ` +
          `${declared ? 'CORRECT' : 'INCORRECT'}`,
      );
    }
    if (archive.correct) correctStates += 1;
  }

  const incorrectStates = states.length - correctStates;
  if ((input.requireDiscriminating ?? true) && (correctStates === 0 || incorrectStates === 0)) {
    fail(
      `screen "${screen.id}" archive verdict is constant across all ${states.length} states — ` +
        'agreement on a non-discriminating space is not evidence',
    );
  }
  return { screenId: screen.id, states: states.length, correctStates, incorrectStates };
}
