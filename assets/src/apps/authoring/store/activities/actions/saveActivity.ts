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
import { updateSequenceItemFromActivity } from '../../groups/layouts/deck/actions/updateSequenceItemFromActivity';
import { selectCurrentGroup } from 'apps/delivery/store/features/groups/slice';
import { diff } from 'deep-object-diff';

export const saveActivity = createAsyncThunk(
  `${ActivitiesSlice}/saveActivity`,
  async (payload: { activity: IActivity; undoable?: boolean }, { dispatch, getState }) => {
    const { activity, undoable = true } = payload;
    const rootState = getState() as any;
    const projectSlug = selectProjectSlug(rootState);
    const resourceId = selectResourceId(rootState);
    const currentActivityState = selectActivityById(rootState, activity.id) as IActivity;
    const group = selectCurrentGroup(rootState);

    const isReadOnlyMode = selectReadOnly(rootState);

    if (!activity.authoring.parts?.length) {
      activity.authoring.parts = [
        {
          id: '__default',
          type: 'janus-text-flow',
          inherited: false,
          owner: 'self', // should be sequenceId, but not sure it's needed here
        },
      ];
    }

    const changeData: ActivityUpdate = {
      title: activity.title as string,
      objectives: activity.objectives as ObjectiveMap,
      content: { ...activity.content, authoring: activity.authoring },
      tags: activity.tags,
    };

    if (!isReadOnlyMode) {
      /*console.log('going to save acivity: ', { changeData, activity });*/
      const editResults = await edit(
        projectSlug,
        resourceId,
        activity.resourceId as number,
        changeData,
        false,
      );

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

      console.log('EDIT SAVE RESULTS', { editResults });

      /*console.log('EDIT SAVE RESULTS', { editResults });*/
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
  },
);

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
        if (!activity.authoring.parts?.length) {
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
