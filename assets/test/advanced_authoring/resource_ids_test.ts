import { configureStore } from '@reduxjs/toolkit';
import { initializeFromContext } from 'apps/authoring/store/page/actions/initializeFromContext';
import { savePage } from 'apps/authoring/store/page/actions/savePage';
import PageSlice from 'apps/authoring/store/page/name';
import pageReducer from 'apps/authoring/store/page/slice';
import ActivitiesSlice from 'apps/delivery/store/features/activities/name';
import activitiesReducer from 'apps/delivery/store/features/activities/slice';
import GroupsSlice from 'apps/delivery/store/features/groups/name';
import groupsReducer from 'apps/delivery/store/features/groups/slice';
import { edit } from 'data/persistence/resource';

jest.mock('apps/authoring/store/app/slice', () => ({
  selectReadOnly: () => false,
  selectProjectSlug: () => 'project',
  selectAppMode: () => 'expert',
}));
jest.mock('apps/authoring/store/history/slice', () => ({ createUndoAction: jest.fn() }));
jest.mock('data/persistence/resource', () => ({ edit: jest.fn() }));
jest.mock('apps/authoring/store/activities/actions/createNew', () => ({
  createNew: () => () => Promise.resolve({ payload: mockActivity }),
}));
jest.mock('apps/authoring/store/groups/layouts/deck/actions/updateActivityPartInheritance', () => ({
  updateActivityPartInheritance: () => ({ type: 'test/inheritance' }),
}));
jest.mock('apps/authoring/store/groups/layouts/deck/actions/updateActivityRules', () => ({
  updateActivityRules: () => ({ type: 'test/rules' }),
}));

const mockActivity = {
  activity_id: 42,
  activityId: 42,
  resourceId: 42,
  activitySlug: 'current-revision',
  typeSlug: 'oli_adaptive',
  title: 'Screen',
  model: { authoring: { parts: [], rules: [] } },
  objectives: {},
};

it.each(['grouped', 'blank', 'ungrouped'])(
  'loads and saves resource IDs in an adaptive lesson (%s)',
  async (mode) => {
    const blank = mode === 'blank';
    const log = jest.spyOn(console, 'log').mockImplementation(() => undefined);
    (edit as jest.Mock).mockResolvedValue({ revision_slug: 'page' });
    const store = configureStore({
      reducer: {
        [PageSlice]: pageReducer,
        [GroupsSlice]: groupsReducer,
        [ActivitiesSlice]: activitiesReducer,
      },
    });
    const reference = {
      type: 'activity-reference',
      activity_id: 42,
      custom: { sequenceId: 'screen-1', sequenceName: 'Screen' },
    };
    try {
      const result = await store.dispatch(
        initializeFromContext({
          config: { activityTypes: [{ slug: 'oli_adaptive' }] },
          context: {
            title: 'Lesson',
            resourceSlug: 'page',
            resourceId: 10,
            objectives: { attached: [] },
            activities: blank
              ? {}
              : { 'current-revision': { ...mockActivity, activityId: undefined } },
            content: {
              custom: { themeId: 'torus-default-light' },
              model: blank
                ? []
                : mode === 'ungrouped'
                ? [{ ...reference, children: [] }]
                : [{ type: 'group', id: 'group', layout: 'deck', children: [reference] }],
            },
          },
        } as any) as any,
      );
      if (result.meta.requestStatus !== 'fulfilled') throw new Error(result.error?.message);
      const group = Object.values(store.getState()[GroupsSlice].entities)[0]!;
      expect(group.children[0]).toEqual(
        expect.objectContaining({
          activity_id: 42,
          resourceId: 42,
          activitySlug: 'current-revision',
        }),
      );

      const saved = await store.dispatch(savePage({ immiediate: true }) as any);
      expect(saved.meta.requestStatus).toBe('fulfilled');
      const calls = (edit as jest.Mock).mock.calls;
      const persisted = calls[calls.length - 1][2].content.model[0].children[0];
      expect(persisted.activity_id).toBe(42);
      expect(persisted).not.toHaveProperty('activitySlug');
      expect(persisted).not.toHaveProperty('resourceId');
    } finally {
      log.mockRestore();
    }
  },
);
