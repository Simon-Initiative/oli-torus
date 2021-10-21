import { createAsyncThunk } from '@reduxjs/toolkit';
import { ObjectiveMap } from 'data/content/activity';
import { ActivityUpdate, edit } from 'data/persistence/activity';
import {
  ActivitiesSlice,
  IActivity,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { selectProjectSlug } from '../../app/slice';
import { selectResourceId } from '../../page/slice';

export const saveActivity = createAsyncThunk(
  `${ActivitiesSlice}/saveActivity`,
  async (payload: { activity: IActivity }, { dispatch, getState }) => {
    const { activity } = payload;
    const rootState = getState() as any;
    const projectSlug = selectProjectSlug(rootState);
    const resourceId = selectResourceId(rootState);

    const changeData: ActivityUpdate = {
      title: activity.title as string,
      objectives: activity.objectives as ObjectiveMap,
      content: { ...activity.content, authoring: activity.authoring },
      tags: activity.tags,
    };
    /* console.log('going to save acivity: ', { changeData, activity }); */
    const editResults = await edit(
      projectSlug,
      resourceId,
      activity.resourceId as number,
      changeData,
      false,
    );
    /* console.log('EDIT SAVE RESULTS', { editResults }); */
    await dispatch(upsertActivity({ activity }));
    return;
  },
);
