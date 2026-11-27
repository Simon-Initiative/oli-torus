import { configureStore } from '@reduxjs/toolkit';
import Ajv from 'ajv';
import fs from 'fs';
import path from 'path';
import {
  transformModelToSchema,
  transformSchemaToModel,
} from 'apps/authoring/components/PropertyEditor/schemas/lesson';
import { createNew as createDeck } from 'apps/authoring/store/groups/layouts/deck/actions/createNew';
import { savePage } from 'apps/authoring/store/page/actions/savePage';
import PageSlice from 'apps/authoring/store/page/name';
import pageReducer, { loadPage } from 'apps/authoring/store/page/slice';
import ActivitiesSlice from 'apps/delivery/store/features/activities/name';
import activitiesReducer from 'apps/delivery/store/features/activities/slice';
import {
  flattenHierarchy,
  getHierarchy,
} from 'apps/delivery/store/features/groups/actions/sequence';
import GroupsSlice from 'apps/delivery/store/features/groups/name';
import groupsReducer, { setGroups } from 'apps/delivery/store/features/groups/slice';
import deliveryPageReducer, { loadPageState } from 'apps/delivery/store/features/page/slice';
import { edit } from 'data/persistence/resource';
import { lesson } from '../advanced_authoring/right_menu/lesson/lesson_mocks';

jest.mock('apps/authoring/store/app/slice', () => ({
  selectReadOnly: () => false,
  selectProjectSlug: () => 'project',
}));
jest.mock('apps/authoring/store/history/slice', () => ({ createUndoAction: jest.fn() }));
jest.mock('data/persistence/resource', () => ({ edit: jest.fn() }));
const uri = 'http://torus.oli.cmu.edu/schemas/v0-1-0/';
const directory = path.resolve(__dirname, '../../../priv/schemas/v0-1-0');
const fixturePath = path.resolve(
  __dirname,
  '../../../test/support/fixtures/adaptive_page_models.json',
);
const ajv = new Ajv({ strict: false, allErrors: true, logger: false });
for (const name of fs.readdirSync(directory).filter((name) => name.endsWith('.json')))
  ajv.addSchema(JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')));
const valid = (name: string, model: unknown) => ajv.getSchema(uri + name + '.schema.json')!(model);
const serialize = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const reference = (id: string, custom: Record<string, unknown> = {}) => ({
  type: 'activity-reference',
  activitySlug: `revision-${id}`,
  resourceId: Number(id),
  custom: { sequenceId: id, sequenceName: `Screen ${id}`, ...custom },
});
const factoryModels = async () => {
  (edit as jest.Mock).mockReset().mockResolvedValue({ revision_slug: 'revision' });
  const store = configureStore({
    reducer: {
      [PageSlice]: pageReducer,
      [GroupsSlice]: groupsReducer,
      [ActivitiesSlice]: activitiesReducer,
    },
  });
  const emptyResult = await store.dispatch(savePage({ immiediate: true }) as any);
  if (emptyResult.meta.requestStatus !== 'fulfilled') throw new Error(emptyResult.error?.message);
  const empty = serialize((edit as jest.Mock).mock.calls[0][2].content);
  const settings = transformSchemaToModel(transformModelToSchema(lesson));
  store.dispatch(
    loadPage({
      ...lesson,
      ...settings,
      revisionSlug: 'revision',
      custom: { ...lesson.custom, ...settings.custom, contentMode: 'expert' },
    }),
  );
  const sequence = [
    reference('1', { isLayer: true }),
    reference('2', { isBank: true, bankShowCount: 2, bankEndTarget: 'next' }),
    reference('3', { layerRef: '2', isLayer: false, isBank: false }),
    reference('4', { layerRef: null }),
  ];
  const clock = jest.spyOn(Date, 'now').mockReturnValue(123456789);
  let group: any;
  try {
    const result = await store.dispatch(createDeck({ children: sequence }) as any);
    group = result.payload;
  } finally {
    clock.mockRestore();
  }
  store.dispatch(setGroups({ groups: [group] }));
  const result = await store.dispatch(savePage({ immiediate: true }) as any);
  if (result.meta.requestStatus !== 'fulfilled') throw new Error(result.error?.message);
  const authoring = serialize((edit as jest.Mock).mock.calls[1][2].content);
  const persisted = serialize(authoring);
  return { empty, authoring, persisted };
};

describe('Adaptive Page JSON schemas', () => {
  it('validates actual page save payloads and corresponding persisted references', async () => {
    const models = await factoryModels();
    expect(models).toEqual(JSON.parse(fs.readFileSync(fixturePath, 'utf8')));
    for (const model of Object.values(models)) {
      expect(valid('page-content-adaptive', model)).toBe(true);
      expect(valid('page-content', model)).toBe(true);
    }
    expect(models.authoring.model[0].children[0]).not.toHaveProperty('resourceId');
  });
  it('passes persisted settings and sequence metadata to the actual delivery reducers', async () => {
    const { persisted } = await factoryModels();
    const state = deliveryPageReducer(undefined, loadPageState({ content: persisted } as any));
    expect(state.enableHistory).toBe(true);
    expect(state.responsiveLayout).toBe(false);
    const groups = groupsReducer(undefined, setGroups({ groups: persisted.model }));
    const children = groups.entities[groups.currentGroupId]!.children;
    expect(children[0].resourceId).toBe(1);
    const flattened = flattenHierarchy(getHierarchy(children));
    expect(flattened.map((entry) => entry.custom.sequenceId)).toEqual(['1', '2', '3', '4']);
  });
  it('validates flowchart/responsive and explicit custom extension settings', async () => {
    const model = (await factoryModels()).persisted;
    model.custom.contentMode = 'flowchart';
    model.custom.responsiveLayout = true;
    (model.custom as any).futureIntegration = { expression: [null, { arbitrary: true }] };
    expect(valid('page-content-adaptive', model)).toBe(true);
    model.custom.defaultScreenWidth = '1200' as any;
    expect(valid('page-content-adaptive', model)).toBe(false);
  });
  it('rejects malformed adaptive models even if a Basic Page version is supplied', () => {
    const model: any = {
      version: '0.1.0',
      advancedAuthoring: true,
      advancedDelivery: true,
      model: [{ type: 'content', children: [] }],
    };
    expect(valid('page-content', model)).toBe(false);
    model.model = [];
    expect(valid('page-content', model)).toBe(true);
    model.advancedDelivery = 'true';
    expect(valid('page-content', model)).toBe(false);
    delete model.advancedDelivery;
    expect(valid('page-content', model)).toBe(false);
    expect(valid('page-content', { version: '0.1.0', model: [] })).toBe(true);
  });
  it('rejects unknown deck and sequence fields and checks bank shape', async () => {
    const model = (await factoryModels()).persisted as any;
    model.model[0].children[1].custom.bankShowCount = '2';
    expect(valid('page-content-adaptive', model)).toBe(false);
    model.model[0].children[1].custom.bankShowCount = 2;
    delete model.model[0].children[1].custom.bankEndTarget;
    expect(valid('page-content-adaptive', model)).toBe(false);
    model.model[0].children[1].custom.bankEndTarget = 'next';
    model.model[0].children[0].custom.sequenceID = 'typo';
    expect(valid('page-content-adaptive', model)).toBe(false);
  });
  it('composes a closed Adaptive Page export with the generic Page envelope', async () => {
    const exported: any = {
      id: 'page',
      type: 'Page',
      title: 'Adaptive',
      isGraded: false,
      objectives: { attached: [] },
      tags: [],
      content: (await factoryModels()).persisted,
    };
    expect(valid('adaptive-page', exported)).toBe(true);
    // Shape emitted by Oli.Interop.Export.pages: objectives are a flat ID array.
    const currentExport = {
      ...exported,
      objectives: ['objective-id'],
      aiEnabled: true,
      purpose: 'foundation',
      relatesTo: [],
      collabSpace: {
        status: 'disabled',
        threaded: true,
        auto_accept: true,
        show_full_history: true,
        anonymous_posting: true,
        participation_min_posts: 0,
        participation_min_replies: 0,
      },
      explanationStrategy: { type: 'none', set_num_attempts: null },
      introContent: {},
      introVideo: null,
      posterImage: null,
      scoringStrategyId: null,
      maxAttempts: 0,
      recommendedAttempts: 0,
      durationMinutes: null,
      fullProgressPct: 100,
      retakeMode: 'normal',
      assessmentMode: 'traditional',
    };
    expect(valid('adaptive-page', currentExport)).toBe(true);
    expect(valid('adaptive-page', { ...currentExport, aiEnabled: 'true' })).toBe(false);

    expect(valid('page', exported)).toBe(true);
    exported.typo = true;
    expect(valid('adaptive-page', exported)).toBe(false);
    delete exported.typo;
    exported.content = { version: '0.1.0', model: [] };
    expect(valid('adaptive-page', exported)).toBe(false);
  });
});
