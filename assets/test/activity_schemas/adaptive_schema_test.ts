import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { defaultModel } from 'components/activities/adaptive/utils';
import { makeFeedback } from 'components/activities/types';
import {
  createAlwaysGoToPath,
  createCorrectPath,
  createEndOfActivityPath,
  createExitPath,
  createIncorrectPath,
  createUnknownPathWithDestination,
} from 'apps/authoring/components/Flowchart/paths/path-factories';
import { createFeedbackAction } from 'apps/authoring/components/Flowchart/rules/create-feedback-action';
import {
  createRuleTemplate,
  defaultNextScreenRule,
  generateRule,
} from 'apps/authoring/components/Flowchart/rules/create-generic-rule';
import { createActivityTemplate } from 'apps/authoring/store/activities/templates/activity';
import { createSimpleText } from 'apps/authoring/store/activities/templates/simpleText';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const fixturePath = path.resolve(__dirname, '../../../test/support/fixtures/adaptive_models.json');
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json')))
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
const validate = ajv.getSchema(uri + 'adaptive.schema.json')!;
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = () => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `adaptive-${++next}`);
};
const factoryModels = async () => {
  resetIds();
  const initial = defaultModel();
  const generic = serialize(initial);
  generic.authoring.parts[0].explanation = makeFeedback('Explanation');
  generic.content = {
    custom: { future: { expression: [null, true] } },
    partsLayout: [await createSimpleText('Nested content')],
  };
  const advanced = createActivityTemplate().model;
  advanced.partsLayout.push(await createSimpleText('Advanced content'));
  advanced.authoring.parts.push({
    id: '__default',
    type: 'janus-text-flow',
    owner: 'self',
    inherited: false,
  });
  const rule = generateRule(
    'Correct',
    [{ fact: 'stage.value', id: 'condition', operator: 'equal', type: 1, value: '1' }],
    'next',
    true,
    1,
    'Feedback',
  );
  advanced.authoring.rules.push(rule, defaultNextScreenRule());
  const flowchart = serialize(advanced);
  flowchart.authoring.flowchart = {
    screenType: 'blank_screen',
    templateApplied: true,
    paths: [
      createCorrectPath('component'),
      createIncorrectPath('component'),
      createAlwaysGoToPath(),
      createEndOfActivityPath(),
      createExitPath(),
      createUnknownPathWithDestination(),
    ],
  };
  flowchart.authoring.variablesRequiredForEvaluation = ['stage.value'];
  return serialize({ initial, generic, advanced, flowchart });
};

describe('Adaptive activity JSON schema', () => {
  beforeEach(resetIds);
  it('validates real activity/screen factories, rule generators and flowchart factories shared with JSV', async () => {
    const models = await factoryModels();
    expect(models).toEqual(JSON.parse(fs.readFileSync(fixturePath, 'utf8')));
    for (const model of Object.values(models)) expect(validate(model)).toBe(true);
  });
  it('validates rule templates and generated feedback actions without expression evaluation', () => {
    const model = createActivityTemplate().model;
    const rule = createRuleTemplate('Rule');
    rule.event.params.actions.push(createFeedbackAction('Feedback'));
    rule.event.params.actions.push({
      type: 'activationPoint',
      params: { prompt: 'Think', kind: 'dot' },
    });
    rule.event.params.actions.push({
      type: 'mutateState',
      params: { target: 'stage.value', targetType: 1, operator: '=', value: 'unparsed {' },
    });
    model.authoring.rules.push(rule);
    expect(validate(serialize(model))).toBe(true);
    (rule.event.params.actions[0].params as any).typo = true;
    expect(validate(serialize(model))).toBe(false);
  });
  it('allows open component payloads and component types while closing layout wrappers', async () => {
    const model = (await factoryModels()).generic as any;
    model.content.partsLayout[0].type = 'future-plugin';
    model.content.partsLayout[0].custom = {
      future: { expression: [null, true] },
      $ref: 'data-only',
    };
    expect(validate(model)).toBe(true);
    model.content.partsLayout[0].typo = true;
    expect(validate(model)).toBe(false);
  });
  it('requires complete part identifiers or generic parts', () => {
    const model = createActivityTemplate().model;
    model.authoring.parts.push({
      id: 'part',
      type: 'janus-input-text',
      owner: 'screen',
      inherited: false,
    });
    expect(validate(model)).toBe(true);
    delete model.authoring.parts[0].owner;
    expect(validate(model)).toBe(false);
    model.authoring.parts[0] = { id: 'part' };
    expect(validate(model)).toBe(false);
  });
  it('validates recursive condition structure while treating values as opaque JSON', () => {
    const model = createActivityTemplate().model;
    const rule = createRuleTemplate('Nested');
    (rule as any).conditions = {
      all: [
        {
          any: [
            { fact: 'stage.value', operator: 'equals', value: { arbitraryMath: [null, true] } },
          ],
        },
      ],
    };
    model.authoring.rules.push(rule);
    expect(validate(model)).toBe(true);
    (rule as any).conditions.all[0].any[0].typo = true;
    expect(validate(model)).toBe(false);
  });
  it('validates exact export dispatch and strict wrappers', () => {
    const validExport = ajv.getSchema(uri + 'adaptive-activity.schema.json')!;
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: 'oli_adaptive',
      title: 'Adaptive',
      content: defaultModel(),
    };
    expect(validExport(exported)).toBe(true);
    exported.subType = 'oli_multiple_choice';
    expect(validExport(exported)).toBe(false);
    exported.subType = 'oli_adaptive';
    exported.content.authoring.typo = true;
    expect(validExport(exported)).toBe(false);
  });
});
