import { createAsyncThunk } from '@reduxjs/toolkit';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { ActivityModelSchema } from 'components/activities/types';
import { ObjectiveMap } from 'data/content/activity';
import { ActivityUpdate, BulkActivityUpdate, bulkEdit, edit } from 'data/persistence/activity';
import {
  ActivitiesSlice,
  IActivity,
  selectActivityById,
  selectAllActivities,
  upsertActivities,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { selectProjectSlug, selectReadOnly } from '../../app/slice';
import { savePage } from '../../page/actions/savePage';
import { selectResourceId, selectState as selectCurrentPage, updatePage } from '../../page/slice';

export const saveActivity = createAsyncThunk(
  `${ActivitiesSlice}/saveActivity`,
  async (payload: { activity: IActivity }, { dispatch, getState }) => {
    const { activity } = payload;
    const rootState = getState() as any;
    const projectSlug = selectProjectSlug(rootState);
    const resourceId = selectResourceId(rootState);

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
      /* console.log('going to save acivity: ', { changeData, activity }); */
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
      if (!currentPage.custom.scoreFixed) {
        // need to check if this update to an activity affects the total score
        if (activity.content?.custom.maxScore !== oldActivityData?.content?.custom.maxScore) {
          await dispatch(savePage());
        }
      }
    }

    return;
  },
);

export const bulkSaveActivity = createAsyncThunk(
  `${ActivitiesSlice}/bulkSaveActivity`,
  async (payload: { activities: IActivity[] }, { dispatch, getState }) => {
    const { activities } = payload;
    const rootState = getState() as any;
    const projectSlug = selectProjectSlug(rootState);
    const pageResourceId = selectResourceId(rootState);

    const isReadOnlyMode = selectReadOnly(rootState);

    dispatch(upsertActivities({ activities }));

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
    }
    return;
  },
);
