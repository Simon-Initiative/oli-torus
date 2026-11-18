import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import { Maybe } from 'tsmonad';
import { CATASchemaV1 } from 'components/activities/check_all_that_apply/transformations/v1';
import { cataV1toV2 } from 'components/activities/check_all_that_apply/transformations/v2';
import { cATAModel, defaultCATAModel } from 'components/activities/check_all_that_apply/utils';
import { LikertActions } from 'components/activities/likert/actions';
import { defaultLikertModel } from 'components/activities/likert/utils';
import { OrderingSchemaV1 } from 'components/activities/ordering/transformations/v1';
import { orderingV1toV2 } from 'components/activities/ordering/transformations/v2';
import { defaultOrderingModel, orderingModel } from 'components/activities/ordering/utils';
import { CreationData, makeFeedback } from 'components/activities/types';
import guid from 'utils/guid';

jest.mock('utils/guid', () => ({ __esModule: true, default: jest.fn() }));

const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json'))) {
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
}
const names = ['ordering', 'check-all-that-apply', 'likert'] as const;
const factories = {
  ordering: defaultOrderingModel,
  'check-all-that-apply': defaultCATAModel,
  likert: defaultLikertModel,
};
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const resetIds = (prefix: string) => {
  let next = 0;
  (guid as jest.Mock).mockImplementation(() => `${prefix}-${++next}`);
};
const factoryModel = (name: typeof names[number]) => {
  resetIds(name);
  const model = factories[name]();
  model.authoring.parts[0].explanation = makeFeedback('Explanation');
  return serialize(model);
};

const fixtures = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, '../../../test/support/fixtures/choice_family_models.json'),
    'utf8',
  ),
);

const valid = (name: string, model: unknown) => ajv.getSchema(uri + name + '.schema.json')!(model);

describe('strict activity JSON schemas', () => {
  beforeEach(() => resetIds('case'));

  it.each(names)('validates actual serialized %s factory output and shared fixtures', (name) => {
    const model = factoryModel(name);
    expect(valid(name, model)).toBe(true);
    expect(model).toEqual(fixtures[name]);
  });

  it.each(['ordering', 'check-all-that-apply'] as const)(
    'validates %s creation-data import output',
    (name) => {
      resetIds('import');
      const data: CreationData = {
        answer: 'A,B',
        choiceA: 'First',
        choiceB: 'Second',
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
        type: name,
        editorSlug: '',
      };
      const model = name === 'ordering' ? orderingModel(data) : cATAModel(data);
      expect(valid(name, serialize(model))).toBe(true);
    },
  );

  it('validates the tagged V1 Ordering variants and actual V1-to-V2 migration', () => {
    const model = defaultOrderingModel();
    const { version: _version, targeted, ...authoring } = model.authoring;
    const simple: OrderingSchemaV1 = {
      stem: model.stem,
      choices: model.choices,
      type: 'SimpleOrdering',
      authoring,
    };
    const targetedModel: OrderingSchemaV1 = {
      ...simple,
      type: 'TargetedOrdering',
      authoring: { ...authoring, targeted },
    };
    for (const legacy of [simple, targetedModel]) {
      expect(valid('ordering', serialize(legacy))).toBe(true);
      expect(valid('ordering', orderingV1toV2(serialize(legacy)))).toBe(true);
    }
  });

  it('validates the tagged V1 CATA variants and actual V1-to-V2 migration', () => {
    const model = defaultCATAModel();
    const { version: _version, targeted, ...rest } = model.authoring;
    const authoring = {
      ...rest,
      incorrect: [[model.choices[1].id], model.authoring.parts[0].responses[1].id] as [
        string[],
        string,
      ],
    };
    const simple: CATASchemaV1 = {
      stem: model.stem,
      choices: model.choices,
      type: 'SimpleCATA',
      authoring,
    };
    const targetedModel: CATASchemaV1 = {
      ...simple,
      type: 'TargetedCATA',
      authoring: { ...authoring, targeted },
    };
    for (const legacy of [simple, targetedModel]) {
      expect(valid('check-all-that-apply', serialize(legacy))).toBe(true);
      expect(valid('check-all-that-apply', cataV1toV2(serialize(legacy)))).toBe(true);
    }
  });

  it('validates Likert Maybe serialization and actual multipart authoring actions', () => {
    resetIds('likert-action');
    const model = defaultLikertModel();
    model.choices[0].value = Maybe.just(5);
    model.items[0].group = Maybe.just('group');
    LikertActions.addItem()(model, () => undefined);
    LikertActions.addChoice()(model, () => undefined);
    expect(valid('likert', serialize(model))).toBe(true);
    expect(serialize(model).choices[0].value).toEqual({ type: 1, value: 5 });
    expect(model.items).toHaveLength(2);
  });

  it.each(names)('rejects unknown fields throughout %s structure', (name) => {
    const paths: (string | number)[][] = [
      [],
      ['authoring'],
      ['stem'],
      ['choices', 0],
      ['authoring', 'parts', 0],
      ['authoring', 'parts', 0, 'hints', 0],
      ['authoring', 'parts', 0, 'responses', 0],
      ['authoring', 'parts', 0, 'responses', 0, 'feedback'],
      ['authoring', 'parts', 0, 'explanation'],
    ];
    if (name === 'likert') paths.push(['items', 0], ['choices', 0, 'value']);
    for (const keys of paths) {
      const model = factoryModel(name);
      const target = keys.reduce((value: any, key) => value[key], model);
      target.explanaton = { content: [] };
      expect(valid(name, model)).toBe(false);
    }
  });

  it.each(names)('uses shared recursive content validation for %s', (name) => {
    const model = factoryModel(name);
    model.authoring.parts[0].explanation!.content = [
      { type: 'table', children: [{ type: 'p', children: [{ text: '' }] }] },
    ] as any;
    expect(valid(name, model)).toBe(false);
  });

  it('checks Ordering colour pairs and Likert Maybe payload types', () => {
    const ordering = factoryModel('ordering') as any;
    ordering.choiceColors = [['choice', '#fff']];
    expect(valid('ordering', ordering)).toBe(true);
    ordering.choiceColors = [['choice', '#fff', 'extra']];
    expect(valid('ordering', ordering)).toBe(false);
    const likert = factoryModel('likert') as any;
    likert.choices[0].value = { type: 1, value: 'bad' };
    expect(valid('likert', likert)).toBe(false);
    likert.choices[0].value = { type: 0, value: 5 };
    expect(valid('likert', likert)).toBe(false);
  });

  it.each(names)('closes and dispatches the %s export envelope', (name) => {
    const slug = {
      ordering: 'oli_ordering',
      'check-all-that-apply': 'oli_check_all_that_apply',
      likert: 'oli_likert',
    }[name];
    const exported: any = {
      id: 'activity',
      type: 'Activity',
      subType: slug,
      content: factoryModel(name),
      title: 'Question',
    };
    expect(valid(name + '-activity', exported)).toBe(true);
    exported.subType = 'oli_multiple_choice';
    expect(valid(name + '-activity', exported)).toBe(false);
    exported.subType = slug;
    exported.titel = 'typo';
    expect(valid(name + '-activity', exported)).toBe(false);
  });
  it.each(names)('models inherited client metadata explicitly for %s', (name) => {
    const model = {
      ...factoryModel(name),
      activityType: { slug: 'oli_multiple_choice' },
      content: { opaque: true },
      resourceId: 1,
    };
    expect(valid(name, model)).toBe(true);
    expect(valid(name, { ...model, activityTyp: 'typo' })).toBe(false);
    expect(valid(name, { ...model, resourceId: '1' })).toBe(false);
  });
});
