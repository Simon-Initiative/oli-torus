import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { MultiInputType } from 'components/activities/multi_input/schema';
import { MultiInputQuestionType, defaultModel } from 'components/activities/multi_input/utils';
import { makeFeedback } from 'components/activities/types';
import { convertMultiInputLegacyMathOnSave } from 'data/activities/model/match_conversion';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const fixturePath = path.resolve(
  __dirname,
  '../../../test/support/fixtures/multi_input_models.json',
);
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const validate = ajv.getSchema(uri + 'multi-input.schema.json')!;
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = () => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `multi-input-${++next}`);
};
const questionTypes: MultiInputQuestionType[] = [
  'dropdown',
  'text',
  'numeric',
  'algebraic',
  'number_with_units',
  'expression_with_units',
  'integer',
  'decimal',
  'fraction',
  'simplified_fraction',
  'latex_direct',
];
const inputTypes: MultiInputType[] = ['dropdown', 'text', 'numeric', 'math', 'math_expression'];
const factoryModels = () => {
  resetIds();
  const text = defaultModel();
  text.authoring.parts[0].explanation = makeFeedback('Explanation');
  const mixed = serialize(text);
  MultiInputActions.setInputType(mixed.inputs[0].id, 'dropdown')(mixed);
  for (const type of ['text', 'numeric', 'math', 'math_expression'] as const) {
    const id = `input-${type}`;
    MultiInputActions.addPart(id)(mixed);
    MultiInputActions.setInputType(id, type)(mixed);
  }
  return serialize({ text, mixed, converted: convertMultiInputLegacyMathOnSave(mixed) });
};

describe('Multi Input JSON schema', () => {
  beforeEach(resetIds);
  it('validates real factory and action fixtures shared with JSV', () => {
    const models = factoryModels();
    expect(models).toEqual(JSON.parse(fs.readFileSync(fixturePath, 'utf8')));
    for (const model of Object.values(models)) expect(validate(model)).toBe(true);
  });
  it.each(inputTypes)('validates all transitions into %s', (type) => {
    for (const previous of inputTypes) {
      const model = defaultModel();
      const id = model.inputs[0].id;
      MultiInputActions.setInputType(id, previous)(model);
      MultiInputActions.setInputType(id, type)(model);
      expect(validate(serialize(model))).toBe(true);
    }
  });
  it.each(questionTypes)('validates transitions into %s question configuration', (type) => {
    for (const previous of ['dropdown', 'text', 'algebraic'] as const) {
      const model = defaultModel();
      const id = model.inputs[0].id;
      MultiInputActions.setQuestionType(id, previous)(model);
      MultiInputActions.setQuestionType(id, type)(model);
      expect(validate(serialize(model))).toBe(true);
    }
  });
  it.each(['numeric', 'math'] as const)('validates legacy %s conversion', (type) => {
    const model = defaultModel();
    MultiInputActions.setInputType(model.inputs[0].id, type)(model);
    expect(validate(serialize(convertMultiInputLegacyMathOnSave(model)))).toBe(true);
  });
  it('validates input sizes, scoring, and contributed responses', () => {
    const model = defaultModel() as any;
    for (const size of ['small', 'medium', 'large', '100pct'] as const) {
      MultiInputActions.setInputSize(model.inputs[0].id, size)(model);
      expect(validate(model)).toBe(true);
    }
    model.customScoring = true;
    model.scoringStrategy = 'total';
    model.submitPerPart = true;
    model.authoring.responses = [
      { users: ['learner'], text: 'answer', type: 'text', part_id: '1', count: 2 },
    ];
    expect(validate(model)).toBe(true);
    model.authoring.responses[0].partId = '1';
    expect(validate(model)).toBe(false);
  });
  it('keeps the math expression opaque and the wrapper strict', () => {
    const model = factoryModels().mixed as any;
    const response = model.authoring.parts[4].responses[0];
    delete response.rule;
    response.matchConfig.math = {
      futureExpression: { children: [null, false, {}] },
      $ref: 'data-only',
    };
    expect(validate(model)).toBe(true);
    response.matchConfig.typo = true;
    expect(validate(model)).toBe(false);
    delete response.matchConfig.typo;
    response.matchConfig.math = [];
    expect(validate(model)).toBe(false);
  });
  it('rejects unknown fields and invalid input variants', () => {
    const model = defaultModel() as any;
    model.inputs[0].size = 'huge';
    expect(validate(model)).toBe(false);
    delete model.inputs[0].size;
    model.inputs[0].inputType = 'dropdown';
    expect(validate(model)).toBe(false);
    model.inputs[0].choiceIds = [];
    expect(validate(model)).toBe(true);
    model.inputs[0].itemConfig = { version: 1, type: 'math_expression', subtype: 'algebraic' };
    expect(validate(model)).toBe(false);
    delete model.inputs[0].itemConfig;
    model.inputs[0].partID = '1';
    expect(validate(model)).toBe(false);
  });
  it('validates a strict export envelope and exact subtype', () => {
    const validExport = ajv.getSchema(uri + 'multi-input-activity.schema.json')!;
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: 'oli_multi_input',
      title: 'Question',
      content: defaultModel(),
    };
    expect(validExport(exported)).toBe(true);
    exported.subType = 'oli_short_answer';
    expect(validExport(exported)).toBe(false);
    exported.subType = 'oli_multi_input';
    exported.typo = true;
    expect(validExport(exported)).toBe(false);
  });
});
