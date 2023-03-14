import { createSelector, createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import { addPath } from '../../components/Flowchart/flowchart-actions/add-path';
import { replacePath } from '../../components/Flowchart/flowchart-actions/replace-path';
import { AllPaths } from '../../components/Flowchart/paths/path-types';
import { deletePath } from '../../components/Flowchart/flowchart-actions/delete-path';
import { AuthoringRootState } from '../rootReducer';
import { FlowchartSlice } from './name';

interface FlowchartState {
  autoOpenPath: string | null; // A rule ID specified here will automatically be open in the UI, useful for when adding a new rule.
}

const initialState = { autoOpenPath: null } as FlowchartState;

const flowchartSlice = createSlice({
  name: 'flowchart',
  initialState,
  reducers: {},
  extraReducers: (builder) => {
    builder.addCase(addPath.fulfilled, (state, action: PayloadAction<AllPaths | null>) => {
      if (!action.payload) return;
      state.autoOpenPath = action.payload.id;
    });

    builder.addCase(replacePath.fulfilled, (state, action: PayloadAction) => {
      state.autoOpenPath = null;
    });

    builder.addCase(deletePath.fulfilled, (state, action: PayloadAction) => {
      state.autoOpenPath = null;
    });
  },
});

export const selectState = (state: AuthoringRootState): FlowchartState =>
  state[FlowchartSlice] as FlowchartState;
export const selectAutoOpenPath = createSelector(selectState, (s) => s.autoOpenPath);

//export const {} = flowchartSlice.actions;
export default flowchartSlice.reducer;
