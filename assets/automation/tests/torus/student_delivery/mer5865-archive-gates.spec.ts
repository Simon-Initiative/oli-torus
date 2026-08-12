import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { validateArchiveCoverage, validateRegistryMetadata } from '@tasks/AdaptiveArchiveGates';
import {
  RawArchivePage,
  correctPlanKind,
  deriveArchiveFacts,
  findAdaptivePages,
  lastNavigableScreenId,
  mcqPartSpec,
  readArchivePage,
  routeSuccessors,
} from '@tasks/AdaptiveArchiveReader';
import { AdaptiveManifest, validateAdaptiveManifest } from '@tasks/AdaptiveManifest';
import {
  archiveVerdict,
  assertPredicateEquivalence,
  engineFactOf,
  mcqStatesFromArchive,
} from '@tasks/AdaptivePredicateEquivalence';

/**
 * MER-5865 step-4 unit 4b — B4-MAN / B4-BIJ / B4-PRED build gates.
 *
 * Every fixture here is SYNTHETIC: the repo carries no archive content and no
 * answer values. The real-archive half runs only when the private artifacts
 * are supplied by env (`MER5865_ARCHIVE_DIR`, `MER5865_ARCHIVE_PAGE`,
 * `MER5865_MANIFEST`), exactly as the step-3 shadow gate does.
 */

type CondFixture = { fact: string; operator: string; value: unknown; type?: number };
type ActionFixture = { type: string; target?: string; kind?: string };
type RuleFixture = {
  name: string;
  correct: boolean;
  disabled?: boolean;
  isDefault?: boolean;
  conditions: CondFixture[];
  actions: ActionFixture[];
};
type PartFixture = { id: string; type: string; src?: string; custom?: Record<string, unknown> };
type ScreenFixture = {
  id: string;
  name: string;
  resourceId: number;
  parts: PartFixture[];
  rules: RuleFixture[];
  combineFeedback?: boolean;
  required?: string[];
};

const PAGE_ID = 900000;
const NAV_ACTIONS: ActionFixture[] = [{ type: 'navigation', target: 'next' }];
const FEEDBACK_NAV_ACTIONS: ActionFixture[] = [
  { type: 'feedback' },
  { type: 'navigation', target: 'next' },
];

const defaultWrong = (): RuleFixture => ({
  name: 'defaultWrong',
  correct: false,
  isDefault: true,
  conditions: [],
  actions: [{ type: 'feedback' }],
});

/** cover → pick → close: navigation entry, one graded multi-select, one terminal. */
function baseScreens(): ScreenFixture[] {
  return [
    {
      id: 's:cover',
      name: 'Cover',
      resourceId: 900001,
      parts: [
        {
          id: 'iframe',
          type: 'janus-capi-iframe',
          src: 'https://w.example/spr-widget-buttonwidget/prod/2.0.*',
        },
      ],
      rules: [{ name: 'correct', correct: true, conditions: [], actions: NAV_ACTIONS }],
    },
    {
      id: 's:pick',
      name: 'Pick',
      resourceId: 900002,
      parts: [
        {
          id: 'Pick',
          type: 'janus-mcq',
          custom: { mcqItems: [{}, {}, {}], multipleSelection: true },
        },
        { id: 'blurb', type: 'janus-text-flow' },
      ],
      rules: [
        {
          name: 'Correct',
          correct: true,
          conditions: [
            {
              fact: 'stage.Pick.selectedChoices',
              operator: 'notContains',
              type: 3,
              value: ['3'],
            },
            {
              fact: 'stage.Pick.numberOfSelectedChoices',
              operator: 'greaterThan',
              type: 1,
              value: 0,
            },
          ],
          actions: FEEDBACK_NAV_ACTIONS,
        },
        {
          name: 'Correct, other branch',
          correct: true,
          conditions: [
            { fact: 'stage.Pick.selectedChoices', operator: 'contains', type: 3, value: ['3'] },
          ],
          actions: FEEDBACK_NAV_ACTIONS,
        },
        {
          name: 'Blank',
          correct: false,
          conditions: [
            {
              fact: 'stage.Pick.numberOfSelectedChoices',
              operator: 'equal',
              type: 1,
              value: 0,
            },
          ],
          actions: [{ type: 'feedback' }],
        },
        defaultWrong(),
      ],
    },
    {
      id: 's:close',
      name: 'Close',
      resourceId: 900003,
      parts: [{ id: 'outro', type: 'janus-text-flow' }],
      rules: [{ name: 'correct', correct: true, conditions: [], actions: FEEDBACK_NAV_ACTIONS }],
    },
  ];
}

function ruleDoc(rule: RuleFixture) {
  return {
    id: `rule.${rule.name}`,
    name: rule.name,
    correct: rule.correct,
    disabled: rule.disabled === true,
    default: rule.isDefault === true,
    priority: 1,
    conditions: { id: `b:${rule.name}`, all: rule.conditions.map((c) => ({ id: 'c', ...c })) },
    event: {
      type: rule.name,
      params: {
        actions: rule.actions.map((a) => ({
          type: a.type,
          params: { target: a.target, kind: a.kind },
        })),
      },
    },
  };
}

function writeArchive(
  screens: ScreenFixture[],
  mutate?: (docs: Record<string, Record<string, unknown>>) => void,
): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mer5865-archive-'));
  const docs: Record<string, Record<string, unknown>> = {};
  docs[String(PAGE_ID)] = {
    id: String(PAGE_ID),
    type: 'Page',
    title: 'Synthetic Deck',
    content: {
      advancedDelivery: true,
      model: [
        {
          type: 'group',
          layout: 'deck',
          children: screens.map((s) => ({
            type: 'activity-reference',
            activity_id: s.resourceId,
            custom: { sequenceId: s.id, sequenceName: s.name },
          })),
        },
      ],
    },
  };
  screens.forEach((s) => {
    docs[String(s.resourceId)] = {
      id: String(s.resourceId),
      type: 'Activity',
      title: s.name,
      content: {
        custom: { combineFeedback: s.combineFeedback === true },
        partsLayout: s.parts.map((p) => ({
          id: p.id,
          type: p.type,
          custom: { ...(p.custom ?? {}), ...(p.src ? { src: p.src } : {}) },
        })),
        authoring: {
          activitiesRequiredForEvaluation: s.required ?? [],
          rules: s.rules.map(ruleDoc),
        },
      },
    };
  });
  if (mutate) mutate(docs);
  Object.keys(docs).forEach((key) =>
    fs.writeFileSync(path.join(dir, `${key}.json`), JSON.stringify(docs[key])),
  );
  return dir;
}

const PICK_EXPECTATIONS = [
  { part_path: 'stage.Pick.numberOfSelectedChoices', predicate: { op: 'greaterThan', value: 0 } },
  { part_path: 'stage.Pick.selectedChoices', predicate: { op: 'minLength', value: 1 } },
];

function baseManifest(): AdaptiveManifest {
  return validateAdaptiveManifest({
    screens: [
      {
        id: 's:cover',
        resource_id: 900001,
        role: 'navigation',
        correct_plan: 'navigation',
        action: { kind: 'in_widget_button', src_fragment: 'spr-widget-buttonwidget' },
      },
      {
        id: 's:pick',
        resource_id: 900002,
        role: 'graded',
        correct_plan: 'feedback',
        operations: [
          {
            id: 'op.pick',
            kind: 'answer',
            family: 'janus-mcq',
            version: '1',
            mode: 'checkboxes',
            directive: { picks: ['first option'], part_id: 'Pick' },
          },
        ],
        expectations: PICK_EXPECTATIONS,
      },
      { id: 's:close', resource_id: 900003, role: 'content', correct_plan: 'feedback' },
    ],
    scenario: [
      { screen_ref: 's:cover', expected_verdict: 'correct' },
      { screen_ref: 's:pick', expected_verdict: 'correct' },
      { screen_ref: 's:close', expected_verdict: 'correct' },
    ],
  });
}

const dirs: string[] = [];
const archive = (screens: ScreenFixture[], mutate?: Parameters<typeof writeArchive>[1]) => {
  const dir = writeArchive(screens, mutate);
  dirs.push(dir);
  return dir;
};

test.afterAll(() => {
  dirs.forEach((dir) => fs.rmSync(dir, { recursive: true, force: true }));
});

/* ------------------------- reader (independent leg) ------------------------ */

test('reader derives inventory, parts, rules and route from the raw archive alone', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  expect(page.screens.map((s) => s.id)).toEqual(['s:cover', 's:pick', 's:close']);
  expect(page.screens[1].parts.map((p) => p.type)).toEqual(['janus-mcq', 'janus-text-flow']);
  expect(page.screens[1].rules.filter((r) => r.correct && !r.disabled)).toHaveLength(2);
  expect(page.screens[1].rules[0].conditions.children).toHaveLength(2);
  expect(page.screens[1].activitiesRequiredForEvaluation).toEqual([]);
  expect(page.screens[1].combineFeedback).toBe(false);
  expect(routeSuccessors(page)).toEqual({
    's:cover': 's:pick',
    's:pick': 's:close',
    's:close': '@end',
  });
  expect(lastNavigableScreenId(page)).toBe('s:close');
  expect(correctPlanKind(page.screens[0])).toBe('navigation');
  expect(correctPlanKind(page.screens[1])).toBe('feedback');
  expect(deriveArchiveFacts(page).rule_prior_state_refs['s:pick']).toEqual([
    'stage.Pick.selectedChoices',
    'stage.Pick.numberOfSelectedChoices',
  ]);
});

test('reader rejects a deleted activity resource', () => {
  const dir = archive(baseScreens(), (docs) => {
    delete docs['900002'];
  });
  expect(() => readArchivePage(dir, PAGE_ID)).toThrow(/resource 900002 is absent/);
});

test('reader rejects a rule hollowed of its conditions block', () => {
  const dir = archive(baseScreens(), (docs) => {
    const content = docs['900002'].content as Record<string, unknown>;
    const authoring = content.authoring as Record<string, unknown>;
    const rules = authoring.rules as Array<Record<string, unknown>>;
    delete rules[0].conditions;
  });
  expect(() => readArchivePage(dir, PAGE_ID)).toThrow(/has no conditions block/);
});

test('reader rejects a missing combineFeedback flag rather than defaulting it', () => {
  const dir = archive(baseScreens(), (docs) => {
    const content = docs['900002'].content as Record<string, unknown>;
    content.custom = {};
  });
  expect(() => readArchivePage(dir, PAGE_ID)).toThrow(/declares no combineFeedback boolean/);
});

test('reader refuses a layer entry instead of guessing what next resolves to', () => {
  const dir = archive(baseScreens(), (docs) => {
    const content = docs[String(PAGE_ID)].content as Record<string, unknown>;
    const group = (content.model as Array<Record<string, unknown>>)[0];
    const children = group.children as Array<Record<string, unknown>>;
    (children[1].custom as Record<string, unknown>).isLayer = true;
  });
  expect(() => readArchivePage(dir, PAGE_ID)).toThrow(/layer\/bank entry/);
});

test('reader refuses an answer-dependent successor', () => {
  const screens = baseScreens();
  screens[1].rules[1].actions = [{ type: 'feedback' }, { type: 'navigation', target: 's:cover' }];
  const page = readArchivePage(archive(screens), PAGE_ID);
  expect(() => routeSuccessors(page)).toThrow(/different targets/);
});

test('reader refuses an answer-dependent plan kind', () => {
  const screens = baseScreens();
  screens[1].rules[1].actions = [{ type: 'navigation', target: 'next' }];
  const page = readArchivePage(archive(screens), PAGE_ID);
  expect(() => correctPlanKind(page.screens[1])).toThrow(/answer-dependent/);
});

/* ------------------------ B4-PRED: exhaustive equivalence ------------------ */

const pickStates = (page: RawArchivePage) => mcqStatesFromArchive(page.screens[1], 'Pick');

test('the enumerated space comes from the archive, never from the caller', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  expect(mcqPartSpec(page.screens[1], 'Pick')).toEqual({ choiceCount: 3, mode: 'checkboxes' });
  expect(pickStates(page)).toHaveLength(16);
  expect(() => mcqPartSpec(page.screens[1], 'blurb')).toThrow(/is a janus-text-flow/);
  const stripped = baseScreens();
  stripped[1].parts[0].custom = { multipleSelection: true };
  const bare = readArchivePage(archive(stripped), PAGE_ID);
  expect(() => mcqPartSpec(bare.screens[1], 'Pick')).toThrow(/declares no mcqItems/);
});

test('every selection is enumerated under both §3.8 encodings', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const states = pickStates(page);
  // 2^3 selections x {native, stringified} — a proof over one encoding leaves
  // the other half of the matcher's normalization contract unproven
  expect(states).toHaveLength(16);
  const twoChosen = states.filter((s) => s.label.indexOf('selected=[1,2]') === 0);
  expect(twoChosen.map((s) => s.label)).toEqual([
    'selected=[1,2] (native)',
    'selected=[1,2] (stringified)',
  ]);
  expect(twoChosen.map((s) => s.facts['stage.Pick.selectedChoices'])).toEqual([[1, 2], '[1,2]']);
  // the count fact is identical across encodings — only the representation moves
  expect(twoChosen.map((s) => s.facts['stage.Pick.numberOfSelectedChoices'])).toEqual([2, 2]);
});

test('an oversized space is refused from the archive count, before it is allocated', () => {
  const screens = baseScreens();
  // 13 choices -> 8192 selections x 2 encodings, over the 4096 default cap
  screens[1].parts[0].custom = {
    mcqItems: new Array(13).fill({}),
    multipleSelection: true,
  };
  const page = readArchivePage(archive(screens), PAGE_ID);
  expect(() => mcqStatesFromArchive(page.screens[1], 'Pick')).toThrow(
    /declares 13 choices — 16384 states, above the 4096 cap/,
  );
});

test('the archive verdict is a disjunction over enabled correct rules, not a first match', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const rules = page.screens[1].rules;
  // choice 3 fails the FIRST correct rule and satisfies the second
  const withThree = await archiveVerdict(rules, {
    'stage.Pick.selectedChoices': [3],
    'stage.Pick.numberOfSelectedChoices': 1,
  });
  const empty = await archiveVerdict(rules, {
    'stage.Pick.selectedChoices': [],
    'stage.Pick.numberOfSelectedChoices': 0,
  });
  expect(withThree.correct).toBe(true);
  expect(empty.correct).toBe(false);
});

test('accepts a declared predicate that agrees on every enumerated state', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const report = await assertPredicateEquivalence({
    screen: page.screens[1],
    expectations: PICK_EXPECTATIONS as never,
    states: pickStates(page),
  });
  expect(report).toEqual({
    screenId: 's:pick',
    states: 16,
    correctStates: 14,
    incorrectStates: 2,
  });
});

test('rejects a predicate that is nearly right and disagrees on one state class', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const nearlyRight = [
    { part_path: 'stage.Pick.numberOfSelectedChoices', predicate: { op: 'greaterThan', value: 1 } },
    { part_path: 'stage.Pick.selectedChoices', predicate: { op: 'minLength', value: 1 } },
  ];
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: nearlyRight as never,
      states: pickStates(page),
    }),
  ).rejects.toThrow(/state selected=\[1\][\s\S]*archive rule chain says CORRECT/);
});

test('rejects an over-narrow predicate that drops the second correct branch', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const overNarrow = [
    { part_path: 'stage.Pick.numberOfSelectedChoices', predicate: { op: 'greaterThan', value: 0 } },
    { part_path: 'stage.Pick.selectedChoices', predicate: { op: 'notContains', value: ['3'] } },
  ];
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: overNarrow as never,
      states: pickStates(page),
    }),
  ).rejects.toThrow(/state selected=\[3\]/);
});

test('rejects a presence-only expectation as unprovable', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: [{ part_path_prefix: 'stage.Pick.' }] as never,
      states: pickStates(page),
    }),
  ).rejects.toThrow(/cannot be proven equivalent/);
});

test('fails loudly instead of skipping when the state space exceeds the cap', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: PICK_EXPECTATIONS as never,
      states: pickStates(page),
      maxStates: 4,
    }),
  ).rejects.toThrow(/enumerates 16 states, above the 4 cap/);
});

test('fails when a rule reads a fact the enumeration does not produce', async () => {
  const screens = baseScreens();
  screens[1].rules[0].conditions.push({
    fact: 'stage.Pick.selectedChoicesText',
    operator: 'contains',
    type: 3,
    value: ['x'],
  });
  const page = readArchivePage(archive(screens), PAGE_ID);
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: PICK_EXPECTATIONS as never,
      states: pickStates(page),
    }),
  ).rejects.toThrow(/selectedChoicesText[\s\S]*state space does not produce/);
});

test('fails when the archive verdict is constant across the whole space', async () => {
  const screens = baseScreens();
  screens[1].rules = [
    { name: 'Correct', correct: true, conditions: [], actions: FEEDBACK_NAV_ACTIONS },
    defaultWrong(),
  ];
  const page = readArchivePage(archive(screens), PAGE_ID);
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: [
        {
          part_path: 'stage.Pick.numberOfSelectedChoices',
          predicate: { op: 'greaterThanInclusive', value: 0 },
        },
      ] as never,
      states: pickStates(page),
    }),
  ).rejects.toThrow(/verdict is constant/);
});

test('refuses an operator this checker does not wire rather than falling back', async () => {
  const screens = baseScreens();
  screens[1].rules[0].conditions[1] = {
    fact: 'stage.Pick.numberOfSelectedChoices',
    operator: 'inRange',
    type: 1,
    value: '1,3',
  };
  const page = readArchivePage(archive(screens), PAGE_ID);
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: PICK_EXPECTATIONS as never,
      states: pickStates(page),
    }),
  ).rejects.toThrow(/operator "inRange", which this checker does not wire/);
});

test('refuses a condition value carrying a janus-script expression', async () => {
  const screens = baseScreens();
  screens[1].rules[0].conditions[1] = {
    fact: 'stage.Pick.numberOfSelectedChoices',
    operator: 'greaterThan',
    type: 1,
    value: '{session.tutorialScore}',
  };
  const page = readArchivePage(archive(screens), PAGE_ID);
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: PICK_EXPECTATIONS as never,
      states: pickStates(page),
    }),
  ).rejects.toThrow(/janus-script expression/);
});

/* --------------------------- B4-MAN: registry metadata --------------------- */

test('accepts registry metadata that the raw archive corroborates', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  expect(() => validateRegistryMetadata(baseManifest(), page)).not.toThrow();
});

test('refuses to pass vacuously on a graded screen that declares no operation', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  delete manifest.screens[1].operations;
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(
    /neither an answer operation nor a cross-screen dependency/,
  );
});

test('rejects an unknown family, version or mode by name', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const withFamily = (patch: Record<string, unknown>) => {
    const manifest = baseManifest();
    Object.assign(manifest.screens[1].operations?.[0] as object, patch);
    return () => validateRegistryMetadata(manifest, page);
  };
  expect(withFamily({ family: 'janus-slider' })).toThrow(/unknown family "janus-slider"/);
  expect(withFamily({ version: '9' })).toThrow(/has no version "9"/);
  expect(withFamily({ mode: 'dropdown' })).toThrow(/unknown mode/);
});

test('rejects a family the archive renders no part for', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  Object.assign(manifest.screens[1].operations?.[0] as object, {
    family: 'janus-input-text',
    mode: undefined,
    directive: { value: 'typed' },
  });
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(
    /archive renders no such part on that screen/,
  );
});

test('rejects a directive the family validator refuses', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  Object.assign(manifest.screens[1].operations?.[0] as object, { directive: { picks: [] } });
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(/non-empty string list/);
});

test('rejects a capi family whose archive major differs from the declared version', () => {
  const screens = baseScreens();
  screens[1].parts.push({
    id: 'Matcher',
    type: 'janus-capi-iframe',
    src: 'https://w.example/spr-widget-matching/prod/3.*',
  });
  const page = readArchivePage(archive(screens), PAGE_ID);
  const manifest = baseManifest();
  (manifest.screens[1].operations as unknown[])[0] = {
    id: 'op.match',
    kind: 'answer',
    family: 'spr-widget-matching',
    version: '2',
    directive: { links: [{ left: 'a', right: 'b' }] },
  };
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(
    /pins family "spr-widget-matching" at major "3"/,
  );
});

test('rejects a capi family the archive serves from no iframe', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  (manifest.screens[1].operations as unknown[])[0] = {
    id: 'op.match',
    kind: 'answer',
    family: 'spr-widget-matching',
    version: '2',
    directive: { links: [{ left: 'a', right: 'b' }] },
  };
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(/no capi iframe on that screen/);
});

/* --------------------------- B4-BIJ: archive coverage ---------------------- */

test('accepts a manifest the raw archive corroborates end to end', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  expect(() => validateArchiveCoverage(baseManifest(), page)).not.toThrow();
});

test('rejects a screen definition missing from the manifest', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  manifest.screens = manifest.screens.filter((s) => s.id !== 's:close');
  manifest.scenario = manifest.scenario.filter((s) => s.screen_ref !== 's:close');
  expect(() => validateArchiveCoverage(manifest, page)).toThrow(
    /archive screen "s:close" has no screen definition/,
  );
});

test('rejects an on-route screen reclassified as an exclusion', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  manifest.scenario = manifest.scenario.filter((s) => s.screen_ref !== 's:pick');
  manifest.exclusions = [{ screen: 's:pick', reason: 'skipped' }];
  expect(() => validateArchiveCoverage(manifest, page)).toThrow(/scenario edge 0/);
});

test('rejects drifted resource identity, plan kind and combine flag', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const drift = (patch: Partial<AdaptiveManifest['screens'][number]>) => {
    const manifest = baseManifest();
    Object.assign(manifest.screens[1], patch);
    return () => validateArchiveCoverage(manifest, page);
  };
  expect(drift({ resource_id: 900099 })).toThrow(/declares resource_id 900099/);
  expect(drift({ correct_plan: 'navigation' })).toThrow(/declares correct_plan navigation/);
  expect(drift({ combine_feedback: true })).toThrow(/declares combine_feedback true/);
});

test('rejects a rule reference with no covering grading expectation', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  manifest.screens[1].expectations = [PICK_EXPECTATIONS[0]] as never;
  expect(() => validateArchiveCoverage(manifest, page)).toThrow(
    /references prior state "stage\.Pick\.selectedChoices" with no covering/,
  );
});

test('rejects a navigation button the archive does not serve, or serves ambiguously', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  (manifest.screens[0].action as { src_fragment: string }).src_fragment = 'spr-widget-absent';
  expect(() => validateArchiveCoverage(manifest, page)).toThrow(/which 0 part srcs/);

  const twoWidgets = baseScreens();
  twoWidgets[0].parts.push({
    id: 'timer',
    type: 'janus-capi-iframe',
    src: 'https://w.example/spr-widget-y/prod/1.*',
  });
  const ambiguous = readArchivePage(archive(twoWidgets), PAGE_ID);
  const loose = baseManifest();
  (loose.screens[0].action as { src_fragment: string }).src_fragment = 'prod';
  expect(() => validateArchiveCoverage(loose, ambiguous)).toThrow(/which 2 part srcs/);
});

test('rejects every role the archive does not derive', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  // role arms the oracle's graded checks — a manifest that relabels a graded
  // screen as content would silently disarm them while every other gate stays green
  const gradedToContent = baseManifest();
  (gradedToContent.screens[1] as { role: string }).role = 'content';
  expect(() => validateArchiveCoverage(gradedToContent, page)).toThrow(
    /declared content but the archive derives graded/,
  );

  const navToGraded = baseManifest();
  (navToGraded.screens[0] as { role: string }).role = 'graded';
  expect(() => validateArchiveCoverage(navToGraded, page)).toThrow(
    /declared graded but the archive derives navigation/,
  );

  const contentToGraded = baseManifest();
  (contentToGraded.screens[2] as { role: string }).role = 'graded';
  expect(() => validateArchiveCoverage(contentToGraded, page)).toThrow(
    /declared graded but the archive derives content/,
  );
});

test('rejects an mcq mode the archive contradicts', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  const operation = manifest.screens[1].operations?.[0] as {
    mode: string;
    directive: Record<string, unknown>;
  };
  // the archive authors Pick as multipleSelection — a radio entry would drive
  // and read back the wrong interaction contract on the same part
  operation.mode = 'radio';
  operation.directive = { pick: 'first option', part_id: 'Pick' };
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(
    /declares mode "radio" but the archive authors part "Pick" as checkboxes/,
  );
});

test('rejects an mcq mode swap on the inferred-ownership branch too', () => {
  // the only mode witness kept part_id, so deleting the inferred-branch call
  // left the suite green; a unique-candidate directive must be checked as well
  const screens = baseScreens();
  screens[1].parts = [screens[1].parts[0]];
  const page = readArchivePage(archive(screens), PAGE_ID);
  const manifest = baseManifest();
  const operation = manifest.screens[1].operations?.[0] as {
    mode: string;
    directive: Record<string, unknown>;
  };
  operation.mode = 'radio';
  operation.directive = { pick: 'first option' };
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(
    /declares mode "radio" but the archive authors part "Pick" as checkboxes/,
  );
});

test('rejects the reverse mode direction: radio archive, checkboxes manifest', () => {
  const screens = baseScreens();
  screens[1].parts[0].custom = { mcqItems: [{}, {}, {}], multipleSelection: false };
  const page = readArchivePage(archive(screens), PAGE_ID);
  const manifest = baseManifest();
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(
    /declares mode "checkboxes" but the archive authors part "Pick" as radio/,
  );
});

test('corroborates every gate kind, and rejects absent, ambiguous and unknown ones', () => {
  const GATES: Array<[string, string]> = [
    ['carousel_view', 'janus-image-carousel'],
    ['flashcard_flip_all', 'janus-flashcards'],
    ['video_start', 'janus-video'],
  ];
  GATES.forEach(([gate, partType], i) => {
    const withControl = baseScreens();
    withControl[1].parts.push({ id: `ctl${i}`, type: partType });
    const okPage = readArchivePage(archive(withControl), PAGE_ID);
    const okManifest = baseManifest();
    (okManifest.screens[1].operations as unknown[]).push({ id: `op.g${i}`, kind: 'gate', gate });
    expect(() => validateRegistryMetadata(okManifest, okPage)).not.toThrow();

    // absent: the base screen renders no such control
    const absentPage = readArchivePage(archive(baseScreens()), PAGE_ID);
    expect(() => validateRegistryMetadata(okManifest, absentPage)).toThrow(
      new RegExp(`${gate}\\) needs exactly one ${partType} part, the archive renders 0`),
    );

    // ambiguous: two owners identify no single control to drive
    const twoControls = baseScreens();
    twoControls[1].parts.push({ id: `ctlA${i}`, type: partType });
    twoControls[1].parts.push({ id: `ctlB${i}`, type: partType });
    const ambiguousPage = readArchivePage(archive(twoControls), PAGE_ID);
    expect(() => validateRegistryMetadata(okManifest, ambiguousPage)).toThrow(
      new RegExp(`${gate}\\) needs exactly one ${partType} part, the archive renders 2`),
    );
  });

  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const unknown = baseManifest();
  (unknown.screens[1].operations as unknown[]).push({
    id: 'op.unknown',
    kind: 'gate',
    gate: 'teleport',
  });
  expect(() => validateRegistryMetadata(unknown, page)).toThrow(/declares unknown gate "teleport"/);
});

test('refuses a state cap that is not a finite positive integer', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  expect(() => mcqStatesFromArchive(page.screens[1], 'Pick', Number.NaN)).toThrow(
    /finite positive integer/,
  );
  expect(() => mcqStatesFromArchive(page.screens[1], 'Pick', Number.POSITIVE_INFINITY)).toThrow(
    /finite positive integer/,
  );
  expect(() => mcqStatesFromArchive(page.screens[1], 'Pick', 0)).toThrow(/finite positive integer/);
});

/**
 * `equal` branches on `Array.isArray(factValue)` (`equality.ts:11`), so a raw
 * `"[1,2]"` falls to scalar comparison while `[1,2]` takes the array branch.
 * A rule using it therefore CHANGES verdict when the archive leg skips the
 * product's assignment step — which is what locks the preprocessing wiring.
 */
function equalityScreens(): ScreenFixture[] {
  const screens = baseScreens();
  screens[1].rules = [
    {
      name: 'Correct',
      correct: true,
      conditions: [
        { fact: 'stage.Pick.selectedChoices', operator: 'equal', type: 3, value: [1, 2] },
      ],
      actions: FEEDBACK_NAV_ACTIONS,
    },
    defaultWrong(),
  ];
  return screens;
}

const EQUALITY_EXPECTATIONS = [
  { part_path: 'stage.Pick.selectedChoices', predicate: { op: 'containsOnly', value: [1, 2] } },
];

test('the archive leg is preprocessed end to end, not just by the exported helper', async () => {
  const page = readArchivePage(archive(equalityScreens()), PAGE_ID);
  // passes only because assertPredicateEquivalence preprocesses before the
  // engine runs; feeding raw wire values makes the stringified states disagree
  const report = await assertPredicateEquivalence({
    screen: page.screens[1],
    expectations: EQUALITY_EXPECTATIONS as never,
    states: pickStates(page),
  });
  expect(report.states).toBe(16);
  expect(report.correctStates).toBe(2);
});

test('a selection whose encodings preprocess to different facts is refused', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const forged = [
    {
      label: 'selected=[1] (native)',
      facts: { 'stage.Pick.selectedChoices': [1], 'stage.Pick.numberOfSelectedChoices': 1 },
    },
    {
      label: 'selected=[1] (stringified)',
      facts: { 'stage.Pick.selectedChoices': '[9]', 'stage.Pick.numberOfSelectedChoices': 1 },
    },
  ];
  await expect(
    assertPredicateEquivalence({
      screen: page.screens[1],
      expectations: PICK_EXPECTATIONS as never,
      states: forged,
    }),
  ).rejects.toThrow(/encodings preprocess to different engine facts/);
});

test('the checker entry point refuses a malformed cap too', async () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const bad = [Number.NaN, Number.POSITIVE_INFINITY, 0, 2.5];
  for (let i = 0; i < bad.length; i += 1) {
    await expect(
      assertPredicateEquivalence({
        screen: page.screens[1],
        expectations: PICK_EXPECTATIONS as never,
        states: pickStates(page),
        maxStates: bad[i],
      }),
    ).rejects.toThrow(/finite positive integer/);
  }
});

test('both encodings preprocess to the same engine fact the product would build', () => {
  // the stringified leg is only the measured input path if the product's own
  // inference turns it into the array the engine actually receives
  expect(engineFactOf('[1,2]')).toEqual([1, 2]);
  expect(engineFactOf([1, 2])).toEqual([1, 2]);
  expect(engineFactOf(2)).toEqual(2);
});

test('rejects a gate operation the archive renders no control for', () => {
  const page = readArchivePage(archive(baseScreens()), PAGE_ID);
  const manifest = baseManifest();
  (manifest.screens[1].operations as unknown[]).push({
    id: 'op.carousel',
    kind: 'gate',
    gate: 'carousel_view',
  });
  expect(() => validateRegistryMetadata(manifest, page)).toThrow(
    /carousel_view\) needs exactly one janus-image-carousel part, the archive renders 0/,
  );
});

test('rejects a graded screen the archive cannot grade', () => {
  const screens = baseScreens();
  screens[1].rules = [
    { name: 'Correct', correct: true, conditions: [], actions: FEEDBACK_NAV_ACTIONS },
    defaultWrong(),
  ];
  const page = readArchivePage(archive(screens), PAGE_ID);
  const manifest = baseManifest();
  manifest.screens[1].expectations = [PICK_EXPECTATIONS[0]] as never;
  // the role check reaches this first and SUBSUMES the gradable check: a screen
  // with no part-conditioned correct rule derives `content`, which is precisely
  // what "cannot grade" means. The gradable check stays as a second net in case
  // the role derivation ever widens.
  expect(() => validateArchiveCoverage(manifest, page)).toThrow(
    /declared graded but the archive derives content/,
  );
});

test('discovers adaptive pages without being told which resource to read', () => {
  const dir = archive(baseScreens());
  expect(findAdaptivePages(dir)).toEqual([{ resourceId: PAGE_ID, title: 'Synthetic Deck' }]);
});

/* ---------------------- real archive (private artifacts) ------------------- */

const archiveDir = process.env.MER5865_ARCHIVE_DIR;
const archivePage = process.env.MER5865_ARCHIVE_PAGE;
const manifestPath = process.env.MER5865_MANIFEST;

/**
 * B4-PRED's witness is FIXED BY THE CONTRACT (§6.3), not chosen at run time: the
 * divergent-rules screen is the one whose arm had to be decided, so a
 * caller-selected screen could prove some other convenient MCQ and report the
 * named gate green while this one stayed untested. Absence or mismatch is red.
 */
const PRED_SCREEN = 'q:1516197466626:752';
const PRED_PART = 'Metacognition';

test.describe('raw archive', () => {
  test.skip(!archiveDir || !archivePage || !manifestPath, 'private archive not provided');

  test('the manifest passes B4-MAN and B4-BIJ against the raw archive', () => {
    const page = readArchivePage(archiveDir as string, parseInt(archivePage as string, 10));
    expect(findAdaptivePages(archiveDir as string).map((p) => p.resourceId)).toContain(
      page.resourceId,
    );
    const manifest = validateAdaptiveManifest(
      JSON.parse(fs.readFileSync(manifestPath as string, 'utf8')),
    );
    validateArchiveCoverage(manifest, page);
    validateRegistryMetadata(manifest, page);
    console.log(`[archive-gates] ${page.screens.length} screens corroborated from "${page.title}"`);
  });

  test('the declared predicate is equivalent to the archive rule chain (B4-PRED)', async () => {
    const page = readArchivePage(archiveDir as string, parseInt(archivePage as string, 10));
    const manifest = validateAdaptiveManifest(
      JSON.parse(fs.readFileSync(manifestPath as string, 'utf8')),
    );
    const screen = page.screens.filter((s) => s.id === PRED_SCREEN)[0];
    const declared = manifest.screens.filter((s) => s.id === PRED_SCREEN)[0];
    // the contract's screen must BE here — its absence is the gate failing, not
    // a reason to skip
    expect(screen, `contract screen "${PRED_SCREEN}" is in the archive`).toBeTruthy();
    expect(declared, `contract screen "${PRED_SCREEN}" is in the manifest`).toBeTruthy();
    expect(
      screen.parts.some((p) => p.id === PRED_PART),
      `contract part "${PRED_PART}" is rendered by the archive`,
    ).toBe(true);
    const report = await assertPredicateEquivalence({
      screen,
      expectations: declared.expectations ?? [],
      states: mcqStatesFromArchive(screen, PRED_PART),
    });
    console.log(
      `[archive-gates] ${report.screenId}: ${report.states} states, ` +
        `${report.correctStates} correct / ${report.incorrectStates} incorrect — all agree`,
    );
  });
});
