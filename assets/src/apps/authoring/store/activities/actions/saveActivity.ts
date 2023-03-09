import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityModelSchema } from 'components/activities/types';
import { ObjectiveMap } from 'data/content/activity';
import { ActivityUpdate, BulkActivityUpdate, bulkEdit, edit } from 'data/persistence/activity';
import {
  IActivity,
  selectActivityById,
  selectAllActivities,
  upsertActivities,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';

import { selectProjectSlug, selectReadOnly } from '../../app/slice';
import { savePage } from '../../page/actions/savePage';
import { selectResourceId, selectState as selectCurrentPage } from '../../page/slice';
import { createUndoAction } from '../../history/slice';
import cloneDeep from 'lodash/cloneDeep';
import memoize from 'lodash/memoize';
import debounce from 'lodash/debounce';

import { updateSequenceItemFromActivity } from '../../groups/layouts/deck/actions/updateSequenceItemFromActivity';
import { selectCurrentGroup } from 'apps/delivery/store/features/groups/slice';
import { diff } from 'deep-object-diff';
import { ProjectSlug, ResourceId } from '../../../../../data/types';
import { SAVE_DEBOUNCE_TIMEOUT, SAVE_DEBOUNCE_OPTIONS } from '../../persistance-options';

export const saveActivity = createAsyncThunk(
  `${ActivitiesSlice}/saveActivity`,
  async (
    payload: { activity: IActivity; undoable?: boolean; immediate?: boolean },
    { dispatch, getState },
  ) => {
    try {
      const { activity, undoable = true } = payload;
      const rootState = getState() as any;
      const projectSlug = selectProjectSlug(rootState);
      const resourceId = selectResourceId(rootState);
      const currentActivityState = selectActivityById(rootState, activity.id) as IActivity;
      const group = selectCurrentGroup(rootState);

      const isReadOnlyMode = selectReadOnly(rootState);

      if (!activity?.authoring?.parts?.length) {
        activity.authoring = activity.authoring || {};
        // There were no parts, so generate a default.
        activity.authoring.parts = [
          {
            id: '__default',
            type: 'janus-text-flow',
            inherited: false,
            owner: 'self', // should be sequenceId, but not sure it's needed here
          },
        ];
      } else if (activity.authoring.parts.length > 1) {
        // don't need the default part if another has been added
        activity.authoring.parts = activity.authoring.parts.filter(
          (part: any) => part.id !== '__default',
        );
      }

      const changeData: ActivityUpdate = {
        title: activity.title as string,
        objectives: activity.objectives as ObjectiveMap,
        content: { ...activity.content, authoring: activity.authoring },
        tags: activity.tags,
      };

      if (!isReadOnlyMode) {
        console.log('going to save acivity: ', { changeData, activity });

        const debouncedEdit = getDebouncedEdit(String(activity.id));

        debouncedEdit(projectSlug, resourceId, activity.resourceId as number, changeData, false);
        if (payload.immediate) {
          await debouncedEdit.flush();
        }

        // grab the activity before it's updated for the score check
        const oldActivityData = selectActivityById(rootState, activity.resourceId as number);

        // update the activitiy before saving the page so that the score is correct
        await dispatch(upsertActivity({ activity }));

        const currentPage = selectCurrentPage(rootState);

        const updatePage =
          activity.title !== currentActivityState?.title ||
          (!currentPage.custom.scoreFixed &&
            activity.content?.custom.maxScore !== oldActivityData?.content?.custom.maxScore);

        if (updatePage) {
          dispatch(updateSequenceItemFromActivity({ activity, group }));
          await dispatch(savePage({}));
        }

        if (undoable) {
          dispatch(
            createUndoAction({
              undo: [saveActivity({ activity: cloneDeep(currentActivityState), undoable: false })],
              redo: [saveActivity({ activity: cloneDeep(activity), undoable: false })],
            }),
          );
        }
      }

      return;
    } catch (e) {
      console.error(`Error during ${ActivitiesSlice}/saveActivity: `, e);
      throw e;
    }
  },
);

/**
 * Debouncing the edit call here is slightly harder than a simple debounce(edit) because we want a unique debounced
 * function for each activity id we might try to save. This way,
 *
 * This:
 *  getDebouncedEdit(activity1.id)(activity1)
 *  getDebouncedEdit(activity1.id)(activity1)
 * Results in a single save.
 *
 * But this:
 *  getDebouncedEdit(activity1.id)(activity1)
 *  getDebouncedEdit(activity2.id)(activity2)
 * Results in two saves.
 *
 * Example uncurried usage:
 *   const debouncedEdit = getDebouncedEdit(activity1.id);
 *   debouncedEdit(activity1);

 */
const wrapEdit = (activityId: string) =>
  debounce(
    async (
      project: ProjectSlug,
      resource: ResourceId,
      activity: ResourceId,
      pendingUpdate: ActivityUpdate,
      releaseLock: boolean,
    ) => {
      console.log('Saving activity: ', {
        activityId,
        project,
        resource,
        activity,
        pendingUpdate,
        releaseLock,
      });
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const editResults = await edit(project, resource, activity, pendingUpdate, releaseLock);
      console.log('EDIT SAVE RESULTS', { editResults });
    },
    SAVE_DEBOUNCE_TIMEOUT,
    SAVE_DEBOUNCE_OPTIONS,
  );
const getDebouncedEdit = memoize(wrapEdit, (activityId) => activityId || 'default');

export const bulkSaveActivity = createAsyncThunk(
  `${ActivitiesSlice}/bulkSaveActivity`,
  async (payload: { activities: IActivity[]; undoable?: boolean }, { dispatch, getState }) => {
    const { activities, undoable = false } = payload;
    const rootState = getState() as any;
    const projectSlug = selectProjectSlug(rootState);
    const pageResourceId = selectResourceId(rootState);
    const currentActivities = selectAllActivities(rootState);
    const isReadOnlyMode = selectReadOnly(rootState);

    console.log(
      'bulkSaveActivity',
      currentActivities,
      activities,
      diff(currentActivities, activities),
    );

    if (!isReadOnlyMode) {
      const updates: BulkActivityUpdate[] = activities.map((activity) => {
        if (!activity?.authoring?.parts?.length) {
          activity.authoring = activity.authoring || {};
          activity.authoring.parts = [
            {
              id: '__default',
              type: 'janus-text-flow',
              inherited: false,
              owner: 'self', // should be sequenceId, but not sure it's needed here
            },
          ];
        }

        const changeData: BulkActivityUpdate = {
          title: activity.title as string,
          objectives: activity.objectives as ObjectiveMap,
          content: activity.content as ActivityModelSchema,
          authoring: activity.authoring,
          resource_id: activity.resourceId as number,
        };
        return changeData;
      });
      await bulkEdit(projectSlug, pageResourceId, updates);
      if (undoable) {
        await dispatch(
          createUndoAction({
            undo: [bulkSaveActivity({ activities: cloneDeep(currentActivities) })],
            redo: [bulkSaveActivity({ activities: cloneDeep(activities) })],
          }),
        );
      }

      dispatch(upsertActivities({ activities }));
    }
    return;
  },
);
