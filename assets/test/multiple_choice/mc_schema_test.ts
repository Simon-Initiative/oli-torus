import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { defaultMCModel, mCModel } from 'components/activities/multiple_choice/utils';
import { CreationData, makeFeedback } from 'components/activities/types';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));

const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const validate = ajv.getSchema(
  'http://torus.oli.cmu.edu/schemas/v0-1-0/multiple-choice.schema.json',
)!;

const factoryModel = () => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `mcq-fixture-${++next}`);
  const model = defaultMCModel();
  model.authoring.parts[0].explanation = makeFeedback('Explanation');
  return model;
};

const fixture = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, '../../../test/support/fixtures/multiple_choice_model.json'),
    'utf8',
  ),
);

describe('Multiple choice JSON Schema', () => {
  it('matches the actual factory including explanation and blank editing states', () => {
    const model = factoryModel();
    expect(validate(model)).toBe(true);
    expect(model).toEqual(fixture);
  });

  it('accepts the factory output after adding targeted feedback', () => {
    const model = factoryModel();
    const response = { ...model.authoring.parts[0].responses[1], id: 'targeted-response' };
    model.authoring.parts[0].responses.splice(1, 0, response);
    model.authoring.targeted.push([[model.choices[1].id], response.id]);
    expect(validate(model)).toBe(true);
  });

  it('accepts the creation-data import helper including its explanation', () => {
    let next = 0;
    (guid as jest.Mock).mockImplementation(() => `import-${++next}`);
    const data: CreationData = {
      answer: 'A',
      choiceA: 'Yes',
      choiceB: 'No',
      choiceC: '',
      choiceD: '',
      choiceE: '',
      choiceF: '',
      correct_feedback: 'Correct',
      incorrect_feedback: 'Try again',
      explanation: 'Here is why',
      hint1: '',
      hint2: '',
      hint3: '',
      objectives: '',
      stem: 'Choose yes',
      tags: '',
      title: 'MCQ',
      type: 'oli_multiple_choice',
      editorSlug: '',
    };
    const model = mCModel(data);
    expect(validate(model)).toBe(true);
    expect(model.authoring.parts[0].explanation).toBeDefined();
  });

  it('recursively rejects malformed explanation content through the shared page schema', () => {
    const model = factoryModel();
    (model.authoring.parts[0].explanation!.content as any) = [
      { type: 'table', children: [{ type: 'p', children: [{ text: '' }] }] },
    ];
    expect(validate(model)).toBe(false);
  });
  it.each([
    { name: 'model', path: [] },
    { name: 'authoring', path: ['authoring'] },
    { name: 'stem', path: ['stem'] },
    { name: 'choice', path: ['choices', 0] },
    { name: 'part', path: ['authoring', 'parts', 0] },
    { name: 'hint', path: ['authoring', 'parts', 0, 'hints', 0] },
    { name: 'response', path: ['authoring', 'parts', 0, 'responses', 0] },
    { name: 'feedback', path: ['authoring', 'parts', 0, 'responses', 0, 'feedback'] },
    { name: 'explanation', path: ['authoring', 'parts', 0, 'explanation'] },
    { name: 'transformation', path: ['authoring', 'transformations', 0] },
  ])('rejects unknown fields on $name', ({ path: keys }) => {
    const model = factoryModel();
    const target = keys.reduce((value: any, key) => value[key], model);
    target.explanaton = { content: [] };
    expect(validate(model)).toBe(false);
  });

  it('allows frequency only on choices while preserving shared element metadata', () => {
    const model = factoryModel();
    model.choices[0].frequency = 2;
    expect(validate(model)).toBe(true);
    (model.stem as any).frequency = 2;
    expect(validate(model)).toBe(false);
    delete (model.stem as any).frequency;
    (model.stem.content[0] as any).customMetadata = { legacy: true };
    expect(validate(model)).toBe(true);
  });
  it('preserves legacy selection while rejecting undeclared legacy fields', () => {
    const model = factoryModel();
    const point = { path: [0, 0], offset: 0 };
    const legacy: any = { model: model.stem.content, selection: { anchor: point, focus: point } };
    (model.stem as any).content = legacy;
    expect(validate(model)).toBe(true);
    legacy.selection.anchor.offest = 1;
    expect(validate(model)).toBe(false);
  });

  it('closes the MCQ export envelope without rejecting its declared metadata', () => {
    const validateExport = ajv.getSchema(
      'http://torus.oli.cmu.edu/schemas/v0-1-0/multiple-choice-activity.schema.json',
    )!;
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: 'oli_multiple_choice',
      content: factoryModel(),
      title: 'Question',
      tags: [],
      objectives: {},
      unresolvedReferences: [],
    };
    expect(validateExport(exported)).toBe(true);
    exported.titel = 'typo';
    expect(validateExport(exported)).toBe(false);
  });
});
