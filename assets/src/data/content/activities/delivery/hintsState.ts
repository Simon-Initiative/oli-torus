import { createReducer, createSlice, PayloadAction } from '@reduxjs/toolkit';
import { RequestHintResponse } from 'components/activities/DeliveryElement';
import { Hint } from 'components/activities/types';
import { AppThunk, slice } from 'data/content/activities/DeliveryState';
import { Maybe } from 'tsmonad';

export const hintsSlice = createSlice({
  name: 'Hints',
  initialState: {
    hints: [] as Hint[],
    hasMoreHints: false,
  },
  reducers: {

  },
});

export const requestHint =
  (
    onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onRequestHint(
      getState().attemptState.attemptGuid,
      getState().attemptState.parts[0].attemptGuid,
    );
    Maybe.maybe(response.hint).lift((hint) => {
      dispatch(slice.actions.addHint(hint));
    });
    dispatch(slice.actions.setHasMoreHints(response.hasMoreHints));
  };
