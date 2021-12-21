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
      /* console.log('EDIT SAVE RESULTS', { editResults }); */
      const currentPage = selectCurrentPage(rootState);
      if (!currentPage.custom.scoreFixed) {
        // need to check if this update to an activity affects the total score
        const oldActivityData = selectActivityById(rootState, activity.resourceId as number);
        if (activity.content?.custom.maxScore !== oldActivityData?.content?.custom.maxScore) {
          const allActivities = selectAllActivities(rootState);
          const sequence = selectSequence(rootState);
          const totalScore = sequence.reduce((acc, sequenceItem) => {
            if (sequenceItem.custom.isLayer || sequenceItem.custom.isBank) {
              return acc;
            }
            if (sequenceItem.resourceId === activity.resourceId) {
              return acc + activity.content?.custom.maxScore;
            }
            const currActivity = allActivities.find((a) => a.id === sequenceItem.resourceId);
            if (!currActivity) {
              return acc;
            }
            return acc + (currActivity?.content?.custom?.maxScore || 0);
          }, 0);
          if (currentPage.custom.totalScore !== totalScore) {
            console.log('updating total score', { totalScore, currentPage, activity });
            await dispatch(savePage({ custom: { ...currentPage.custom, totalScore } }));
            await dispatch(updatePage({ custom: { ...currentPage.custom, totalScore } }));
          }
        }
      }
    }

    await dispatch(upsertActivity({ activity }));
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
