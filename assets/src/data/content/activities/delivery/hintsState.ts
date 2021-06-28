import { createReducer, createSlice, PayloadAction } from '@reduxjs/toolkit';
import { RequestHintResponse } from 'components/activities/DeliveryElement';
import { Hint } from 'components/activities/types';
import { AppThunk } from 'data/content/activities/DeliveryState';
import { Maybe } from 'tsmonad';

export const hintsSlice = createSlice({
  name: 'Hints',
  initialState: {
    hints: [] as Hint[],
    hasMoreHints: false,
  },
  reducers: {
    setHints(state, action: PayloadAction<Hint[]>) {
      state.hints = action.payload;
    },
    addHint(state, action: PayloadAction<Hint>) {
      state.hints.push(action.payload);
    },
    setHasMoreHints(state, action: PayloadAction<boolean>) {
      state.hasMoreHints = action.payload;
    },
    clearHints(state) {
      state.hints = [];
    },
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
      dispatch(hintsSlice.actions.addHint(hint));
    });
    dispatch(hintsSlice.actions.setHasMoreHints(response.hasMoreHints));
  };
