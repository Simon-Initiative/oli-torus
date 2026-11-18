import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { FileUploadActions } from 'components/activities/file_upload/actions';
import { defaultModel as defaultFileUpload } from 'components/activities/file_upload/utils';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { InputType } from 'components/activities/short_answer/schema';
import {
  defaultModel as defaultShortAnswer,
  sAModel,
} from 'components/activities/short_answer/utils';
import { CreationData, makeFeedback } from 'components/activities/types';
import { MathExpressionQuestionType } from 'data/activities/model/match';
import { convertShortAnswerLegacyMathOnSave } from 'data/activities/model/match_conversion';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const valid = (name: string, model: unknown) => ajv.getSchema(uri + name + '.schema.json')!(model);
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = (prefix: string) => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `${prefix}-${++next}`);
};
const inputTypes: InputType[] = [
  'text',
  'numeric',
  'textarea',
  'math',
  'math_expression',
  'vlabvalue',
];
const questionTypes: MathExpressionQuestionType[] = [
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
const factoryModels = () => {
  resetIds('file-upload');
  const fileUpload = defaultFileUpload();
  fileUpload.authoring.parts[0].explanation = makeFeedback('Explanation');
  resetIds('short-answer');
  const shortAnswer = defaultShortAnswer();
  shortAnswer.authoring.parts[0].explanation = makeFeedback('Explanation');
  resetIds('math-expression');
  const math = defaultShortAnswer();
  ShortAnswerActions.setQuestionType('algebraic', '1')(math);
  math.authoring.parts[0].explanation = makeFeedback('Explanation');
  return serialize({
    'file-upload': fileUpload,
    'short-answer': shortAnswer,
    'math-expression': math,
  });
};

const fixtures = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, '../../../test/support/fixtures/upload_short_answer_models.json'),
    'utf8',
  ),
);

describe('File Upload and Short Answer JSON schemas', () => {
  beforeEach(() => resetIds('case'));

  it('validates actual serialized factory output and shared fixtures', () => {
    const models = factoryModels();
    expect(models).toEqual(fixtures);
    expect(valid('file-upload', models['file-upload'])).toBe(true);
    expect(valid('short-answer', models['short-answer'])).toBe(true);
    expect(valid('short-answer', models['math-expression'])).toBe(true);
  });

  it.each(inputTypes)('validates the %s input-type action output', (inputType) => {
    const model = defaultShortAnswer();
    ShortAnswerActions.setInputType(inputType, '1')(model);
    expect(valid('short-answer', serialize(model))).toBe(true);
  });

  it.each(questionTypes)('validates the %s question-type action output', (questionType) => {
    const model = defaultShortAnswer();
    ShortAnswerActions.setQuestionType(questionType, '1')(model);
    expect(valid('short-answer', serialize(model))).toBe(true);
  });

  it.each(['numeric', 'math'] as const)('validates legacy %s conversion on save', (inputType) => {
    const model = defaultShortAnswer();
    ShortAnswerActions.setInputType(inputType, '1')(model);
    expect(valid('short-answer', convertShortAnswerLegacyMathOnSave(model))).toBe(true);
  });

  it.each(['text', 'number', 'paragraph', 'math', 'math_expression', 'expression'])(
    'validates %s creation-data import',
    (type) => {
      const data: CreationData = {
        answer: '2*x',
        choiceA: '',
        choiceB: '',
        choiceC: '',
        choiceD: '',
        choiceE: '',
        choiceF: '',
        correct_feedback: 'Correct',
        incorrect_feedback: 'Try again',
        explanation: 'Explanation',
        hint1: '',
        hint2: '',
        hint3: '',
        objectives: '',
        stem: 'Question',
        tags: '',
        title: 'Question',
        type,
        editorSlug: '',
      };
      expect(valid('short-answer', serialize(sAModel(data)))).toBe(true);
    },
  );

  it('supports numeric FileSpec action output without imposing upload policy', () => {
    const model = defaultFileUpload();
    FileUploadActions.editFileSpec({ accept: '.pdf', maxCount: 2, maxSizeInBytes: 1024 })(model);
    expect(valid('file-upload', model)).toBe(true);
    (model.fileSpec as any).maxCount = '2';
    expect(valid('file-upload', model)).toBe(false);
    model.fileSpec.maxCount = 2;
    (model.fileSpec as any).maxCout = 2;
    expect(valid('file-upload', model)).toBe(false);
  });

  it('treats matchConfig.math as an opaque object while closing its wrapper', () => {
    const model = factoryModels()['math-expression'] as any;
    const response = model.authoring.parts[0].responses[0];
    response.matchConfig.math = {
      arbitraryNewExpression: { children: [null, 1, { unknown: true }] },
      $ref: 'not-a-schema-reference',
    };
    delete response.rule;
    expect(valid('short-answer', model)).toBe(true);
    response.matchConfig.matth = {};
    expect(valid('short-answer', model)).toBe(false);
    delete response.matchConfig.matth;
    response.matchConfig.math = 'not an object';
    expect(valid('short-answer', model)).toBe(false);
  });

  it('validates item configuration fields separately from the opaque expression', () => {
    const model = factoryModels()['math-expression'] as any;
    model.itemConfig.config.sampling.includeSpecialPoints = 'yes';
    expect(valid('short-answer', model)).toBe(false);
    model.itemConfig.config.sampling.includeSpecialPoints = true;
    model.itemConfig.subtyp = 'algebraic';
    expect(valid('short-answer', model)).toBe(false);
  });

  it.each(['file-upload', 'short-answer'] as const)(
    'rejects unknown %s wrapper fields and wrong export subtype',
    (name) => {
      const model = factoryModels()[name] as any;
      model.authoring.parts[0].explanaton = {};
      expect(valid(name, model)).toBe(false);
      delete model.authoring.parts[0].explanaton;
      const exported: any = {
        id: 'activity',
        type: 'Activity',
        subType: name === 'file-upload' ? 'oli_file_upload' : 'oli_short_answer',
        title: 'Question',
        content: model,
      };
      expect(valid(name + '-activity', exported)).toBe(true);
      exported.subType = 'oli_multiple_choice';
      expect(valid(name + '-activity', exported)).toBe(false);
    },
  );
});
