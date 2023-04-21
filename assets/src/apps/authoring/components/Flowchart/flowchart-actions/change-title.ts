import { EntityId, createAsyncThunk } from '@reduxjs/toolkit';
import { clone, cloneT } from '../../../../../utils/common';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';

interface ReplacePathPayload {
  screenId: EntityId;
  newTitle: string;
}

export const changeTitle = createAsyncThunk(
  `${FlowchartSlice}/changeTitle`,
  async (payload: ReplacePathPayload, { dispatch, getState }) => {
    const { newTitle, screenId } = payload;

    const rootState = getState() as AuthoringRootState;

    const screen = cloneT(selectActivityById(rootState, screenId));
    if (!screen) return;
    const modifiedScreen = clone(screen);
    modifiedScreen.title = newTitle;

    dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
    await dispatch(upsertActivity({ activity: modifiedScreen }));
  },
);
