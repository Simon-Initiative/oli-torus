import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { DirectedDiscussionActions } from 'components/activities/directed-discussion/actions';
import { DDParticipationDefinition } from 'components/activities/directed-discussion/schema';
import { defaultDDModel } from 'components/activities/directed-discussion/utils';
import { Transform, makeFeedback, makeTransformation } from 'components/activities/types';
import { MatchConfigs } from 'data/activities/model/match';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const fixturePath = path.resolve(
  __dirname,
  '../../../test/support/fixtures/directed_discussion_models.json',
);
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const validate = ajv.getSchema(uri + 'directed-discussion.schema.json')!;
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = () => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `directed-discussion-${++next}`);
};
const participation: DDParticipationDefinition = {
  minPosts: 2,
  maxPosts: 4,
  minReplies: 3,
  maxReplies: 6,
  maxWordLength: 250,
};
const factoryModels = () => {
  resetIds();
  const initial = defaultDDModel();
  const edited = serialize(initial);
  DirectedDiscussionActions.editParticipation(participation)(edited);
  StemActions.editStemAndPreviewText([
    { type: 'p', children: [{ text: 'Discuss the evidence.' }] },
  ])(edited);
  StemActions.changeEditorMode('markdown')(edited);
  StemActions.changeTextDirection('rtl')(edited);
  edited.authoring.parts[0].explanation = makeFeedback('Explanation');
  edited.authoring.transformations.push(makeTransformation('choices', Transform.shuffle, true));
  return serialize({ initial, edited });
};

describe('Directed Discussion JSON schema', () => {
  beforeEach(resetIds);

  it('validates real factory output and editor actions against shared JSV fixtures', () => {
    const models = factoryModels();
    expect(models).toEqual(JSON.parse(fs.readFileSync(fixturePath, 'utf8')));
    for (const model of Object.values(models)) expect(validate(model)).toBe(true);
  });

  it.each([
    participation,
    { minPosts: -1, maxPosts: 1, minReplies: -2, maxReplies: 1, maxWordLength: -5 },
    { minPosts: 4, maxPosts: 1, minReplies: 6, maxReplies: 2, maxWordLength: 300 },
    { minPosts: 4, maxPosts: 0, minReplies: 6, maxReplies: 0, maxWordLength: 0 },
  ])('validates participation action output %j', (settings) => {
    const model = defaultDDModel();
    DirectedDiscussionActions.editParticipation(settings)(model);
    expect(validate(serialize(model))).toBe(true);
  });

  it.each(Object.keys(participation))('requires a numeric participation.%s field', (field) => {
    const model = defaultDDModel() as any;
    model.participation[field] = '2';
    expect(validate(model)).toBe(false);
    delete model.participation[field];
    expect(validate(model)).toBe(false);
  });

  it('requires the exact authoring version and closes the authoring block', () => {
    const model = defaultDDModel() as any;
    for (const version of [undefined, null, '1', 0, 2]) {
      model.authoring.version = version;
      expect(validate(serialize(model))).toBe(false);
    }
    model.authoring.version = 1;
    expect(validate(model)).toBe(true);
    model.authoring.previewText = 'Not declared or emitted by the discussion model';
    expect(validate(model)).toBe(false);
  });

  it('types numeric settings without adding participation domain checks', () => {
    const model = defaultDDModel();
    model.maxWords = -2.5;
    model.participation = {
      minPosts: 10.5,
      maxPosts: -1,
      minReplies: 3,
      maxReplies: 1,
      maxWordLength: -4.5,
    };
    expect(validate(model)).toBe(true);
    (model as any).maxWords = '250';
    expect(validate(model)).toBe(false);
  });

  it('supports generic Part responses and the shared opaque math boundary', () => {
    const model = defaultDDModel() as any;
    const response = model.authoring.parts[0].responses[0];
    response.matchConfig = {
      version: 1,
      type: 'math_expression',
      math: { futurePayload: [null, { unknown: true }], $ref: 'data-only' },
    };
    delete response.rule;
    expect(validate(model)).toBe(true);
    response.matchConfig.typo = true;
    expect(validate(model)).toBe(false);
    response.matchConfig = MatchConfigs.always();
    expect(validate(model)).toBe(true);
  });

  it('validates exact export dispatch and strict fields', () => {
    const validExport = ajv.getSchema(uri + 'directed-discussion-activity.schema.json')!;
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: 'oli_directed_discussion',
      title: 'Discussion',
      content: defaultDDModel(),
    };
    expect(validExport(exported)).toBe(true);
    exported.subType = 'oli_multi_input';
    expect(validExport(exported)).toBe(false);
    exported.subType = 'oli_directed_discussion';
    exported.typo = true;
    expect(validExport(exported)).toBe(false);
  });
});
