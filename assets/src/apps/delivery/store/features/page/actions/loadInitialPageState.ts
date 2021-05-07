import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from '../../../rootReducer';
import { loadActivities, loadActivityState } from '../../activities/slice';
import { LayoutType, selectCurrentGroup, setGroups } from '../../groups/slice';
import { loadPageState, PageSlice, PageState } from '../slice';

export const loadInitialPageState = createAsyncThunk(
  `${PageSlice}/loadInitialPageState`,
  async (params: PageState, thunkApi) => {
    const { dispatch, getState } = thunkApi;

    dispatch(loadPageState(params));

    const groups = params.content.model.filter((item: any) => item.type === 'group');
    const otherTypes = params.content.model.filter((item: any) => item.type !== 'group');
    // for now just stick them into a group, this isn't reallly thought out yet
    // and there is technically only 1 supported layout type atm
    if (otherTypes.length) {
      groups.push({ type: 'group', layout: 'deck', children: [...otherTypes] });
    }
    // wait for this to resolve so that state will be updated
    await dispatch(setGroups({ groups }));

    const currentGroup = selectCurrentGroup(getState() as RootState);
    if (currentGroup?.layout === LayoutType.DECK) {
      if (params.previewMode) {
        // need to load activities from the authoring api
        const activityIds = currentGroup.children.map((child: any) => child.activity_id);
        dispatch(loadActivities(activityIds));
      } else {
        // need to load activities from the delivery (attempt) api
        const attemptGuids = Object.keys(params.activityGuidMapping).map((activityResourceId) => {
          const { attemptGuid } = params.activityGuidMapping[activityResourceId];
          return attemptGuid;
        });
        dispatch(loadActivityState(attemptGuids));
      }
    }
  },
);
