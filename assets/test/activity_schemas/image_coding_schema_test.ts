import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { ICActions } from 'components/activities/image_coding/actions';
import { defaultICModel } from 'components/activities/image_coding/utils';
import { RichText, makeFeedback, makeResponse } from 'components/activities/types';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const fixturePath = path.resolve(
  __dirname,
  '../../../test/support/fixtures/image_coding_models.json',
);
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const validate = ajv.getSchema(uri + 'image-coding.schema.json')!;
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = () => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `image-coding-${++next}`);
};
const noPost = () => {};
const text = (value: string, id: string): RichText => [
  { id, type: 'p', children: [{ text: value }] },
];
const factoryModels = () => {
  resetIds();
  const initial = defaultICModel();
  const edited = serialize(initial);
  ICActions.editStem(text('Modify the image.', 'image-coding-stem-paragraph'))(edited, noPost);
  ICActions.editStarterCode('const image = new SimpleImage("image.png");')(edited, noPost);
  ICActions.editSolutionCode('print(image);')(edited, noPost);
  ICActions.editTolerance(2.5)(edited, noPost);
  ICActions.editRegex('^result$')(edited, noPost);
  ICActions.editIsExample(true)(edited, noPost);
  ICActions.addResourceURL('/media/image.png')(edited, noPost);
  ICActions.addResourceURL('/media/data.csv')(edited, noPost);
  ICActions.addResourceURL('/media/image.png')(edited, noPost);
  ICActions.removeResourceURL('/media/data.csv')(edited, noPost);
  ICActions.editFeedback(0, text('Try again.', 'image-coding-feedback-paragraph'))(edited, noPost);
  ICActions.editFeedbackEditorType(0, 'markdown')(edited, noPost);
  ICActions.editFeedbackTextDirection(0, 'rtl')(edited, noPost);
  ICActions.addCognitiveHint()(edited, noPost);
  ICActions.editHint(
    edited.authoring.parts[0].hints[0].id,
    text('Inspect each pixel.', 'image-coding-hint-paragraph'),
  )(edited, noPost);
  ICActions.removeHint(edited.authoring.parts[0].hints[1].id)(edited, noPost);
  edited.authoring.parts[0].explanation = makeFeedback('Explanation');
  return serialize({ initial, edited });
};

describe('Image Coding JSON schema', () => {
  beforeEach(resetIds);
  it('validates factory and real editor action fixtures shared with JSV', () => {
    const models = factoryModels();
    expect(models).toEqual(JSON.parse(fs.readFileSync(fixturePath, 'utf8')));
    for (const model of Object.values(models)) expect(validate(model)).toBe(true);
    expect(models.initial.authoring.parts[0].responses).toEqual([]);
  });
  it.each([
    'stem',
    'isExample',
    'starterCode',
    'solutionCode',
    'resourceURLs',
    'tolerance',
    'regex',
    'feedback',
    'authoring',
  ])('requires the %s root field', (field) => {
    const model = defaultICModel() as any;
    delete model[field];
    expect(validate(model)).toBe(false);
  });
  it('rejects numeric strings emitted by the existing tolerance input handler', () => {
    const model = defaultICModel();
    ICActions.editTolerance('2' as any)(model, noPost);
    expect(validate(serialize(model))).toBe(false);
  });
  it('keeps code, regex and resource addresses as strings without evaluating domain policies', () => {
    const model = defaultICModel();
    ICActions.editTolerance(-1.5)(model, noPost);
    ICActions.editRegex('[')(model, noPost);
    ICActions.editStarterCode('not valid code {')(model, noPost);
    ICActions.addResourceURL('relative or future resource address')(model, noPost);
    expect(validate(model)).toBe(true);
  });
  it('rejects unknown authoring fields and malformed feedback', () => {
    const model = defaultICModel() as any;
    model.authoring.version = 1;
    expect(validate(model)).toBe(false);
    delete model.authoring.version;
    model.feedback[0].typo = true;
    expect(validate(model)).toBe(false);
    delete model.feedback[0].typo;
    model.feedback = ['feedback'];
    expect(validate(model)).toBe(false);
  });
  it('supports inherited generic response structure with an opaque math leaf', () => {
    const model = defaultICModel() as any;
    const response = makeResponse('', 1, 'Correct') as any;
    response.matchConfig = {
      version: 1,
      type: 'math_expression',
      math: { future: [null, { arbitrary: true }], $ref: 'data-only' },
    };
    delete response.rule;
    model.authoring.parts[0].responses.push(response);
    expect(validate(model)).toBe(true);
    response.matchConfig.typo = true;
    expect(validate(model)).toBe(false);
  });
  it('validates strict export dispatch', () => {
    const validExport = ajv.getSchema(uri + 'image-coding-activity.schema.json')!;
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: 'oli_image_coding',
      title: 'Image Coding',
      content: defaultICModel(),
    };
    expect(validExport(exported)).toBe(true);
    exported.subType = 'oli_directed_discussion';
    expect(validExport(exported)).toBe(false);
    exported.subType = 'oli_image_coding';
    exported.typo = true;
    expect(validExport(exported)).toBe(false);
  });
});
