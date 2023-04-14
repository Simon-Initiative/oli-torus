import { EntityId, createSelector, createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import { addPath } from '../../components/Flowchart/flowchart-actions/add-path';
import { replacePath } from '../../components/Flowchart/flowchart-actions/replace-path';
import { AllPaths } from '../../components/Flowchart/paths/path-types';
import { deletePath } from '../../components/Flowchart/flowchart-actions/delete-path';
import { AuthoringRootState } from '../rootReducer';
import { FlowchartSlice } from './name';
import { ErrorInfo } from 'react';
import { IActivity } from '../../../delivery/store/features/activities/slice';

interface ReportErrorPayload {
  error: string | null;
  info: ErrorInfo | null;
  title: string;
  message: string;
  failedActivity?: IActivity | null;
}
interface FlowchartState {
  autoOpenPath: string | null; // A rule ID specified here will automatically be open in the UI, useful for when adding a new rule.
  apiError: ReportErrorPayload | null;
}

const initialState = { autoOpenPath: null } as FlowchartState;

const flowchartSlice = createSlice({
  name: 'flowchart',
  initialState,
  reducers: {
    reportAPIError(state, action: PayloadAction<ReportErrorPayload>) {
      const { message, ...rest } = action.payload;
      console.error(`🔥Error Reported:\n > ${message}`, rest);
      if (!state.apiError) {
        // Keep the first error reported
        state.apiError = action.payload;
      }
    },
    clearError(state) {
      state.apiError = null;
    },
  },
  extraReducers: (builder) => {
    builder.addCase(addPath.fulfilled, (state, action: PayloadAction<AllPaths | null>) => {
      if (!action.payload) return;
      state.autoOpenPath = action.payload.id;
    });

    builder.addCase(replacePath.fulfilled, (state) => {
      state.autoOpenPath = null;
    });

    builder.addCase(deletePath.fulfilled, (state) => {
      state.autoOpenPath = null;
    });
  },
});

export const selectState = (state: AuthoringRootState): FlowchartState =>
  state[FlowchartSlice] as FlowchartState;
export const selectAutoOpenPath = createSelector(selectState, (s) => s.autoOpenPath);
export const selectApiError = createSelector(selectState, (s) => s.apiError);
export const { reportAPIError, clearError } = flowchartSlice.actions;
export default flowchartSlice.reducer;
