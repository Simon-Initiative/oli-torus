import { AnyAction, createSlice, PayloadAction, ThunkAction } from '@reduxjs/toolkit';
import {
  EvaluationResponse,
  RequestHintResponse,
  ResetActivityResponse,
} from 'components/activities/DeliveryElement';
import {
  ActivityState,
  ChoiceId,
  FeedbackAction,
  Hint,
  PartResponse,
  Success,
} from 'components/activities/types';
import { Maybe } from 'tsmonad';

export type AppThunk<ReturnType = void> = ThunkAction<
  ReturnType,
  ActivityDeliveryState,
  unknown,
  AnyAction
>;

export interface ActivityDeliveryState {
  attemptState: ActivityState;
  selectedChoices: ChoiceId[];
  hints: Hint[];
  hasMoreHints: boolean;
}
export const activityDeliverySlice = createSlice({
  name: 'ActivityDelivery',
  initialState: {} as ActivityDeliveryState,
  reducers: {
    activitySubmissionReceived(state, action: PayloadAction<EvaluationResponse>) {
      if (action.payload.actions.length > 0) {
        const { score, out_of, feedback, error } = action.payload.actions[0] as FeedbackAction;
        state.attemptState = {
          ...state.attemptState,
          score,
          outOf: out_of,
          parts: [{ ...state.attemptState.parts[0], feedback, error }],
        };
      }
    },
    setSelectedChoices(state, action: PayloadAction<ChoiceId[]>) {
      state.selectedChoices = action.payload;
    },
    clearSelectedChoices(state) {
      state.selectedChoices = [];
    },
    setAttemptState(state, action: PayloadAction<ActivityState>) {
      state.attemptState = action.payload;
    },
    updateChoiceSelectionMultiple(state, action: PayloadAction<string>) {
      state.selectedChoices.find((choiceId) => choiceId === action.payload)
        ? (state.selectedChoices = state.selectedChoices.filter((id) => id !== action.payload))
        : state.selectedChoices.push(action.payload);
    },
    updateChoiceSelectionSingle(state, action: PayloadAction<string>) {
      state.selectedChoices = [action.payload];
    },
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
const slice = activityDeliverySlice;

export const requestHint =
  (
    onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onRequestHint(
      getState().attemptState.attemptGuid,
      getState().attemptState.parts[0].attemptGuid,
    );
    Maybe.maybe(response.hint).lift((hint) => dispatch(slice.actions.addHint(hint)));
    dispatch(slice.actions.setHasMoreHints(response.hasMoreHints));
  };

export const selectedChoicesToInput = (state: ActivityDeliveryState) =>
  state.selectedChoices.join(' ');
export const selectAttemptState = (state: ActivityDeliveryState) => state.attemptState;
export const isEvaluated = (state: ActivityDeliveryState) =>
  selectAttemptState(state).score !== null;

export const resetAction =
  (onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>): AppThunk =>
  async (dispatch, getState) => {
    const response = await onResetActivity(getState().attemptState.attemptGuid);
    dispatch(slice.actions.clearSelectedChoices());
    dispatch(slice.actions.clearHints());
    dispatch(slice.actions.setAttemptState(response.attemptState));
    dispatch(slice.actions.setHasMoreHints(getState().attemptState.parts[0].hasMoreHints));
  };

export const submit =
  (
    onSubmitActivity: (
      attemptGuid: string,
      partResponses: PartResponse[],
    ) => Promise<EvaluationResponse>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onSubmitActivity(getState().attemptState.attemptGuid, [
      {
        attemptGuid: getState().attemptState.parts[0].attemptGuid,
        response: { input: selectedChoicesToInput(getState()) },
      },
    ]);
    dispatch(slice.actions.activitySubmissionReceived(response));
  };

// TODO in follow-up activities - make generic
export const initializeState =
  (state: ActivityState): AppThunk =>
  async (dispatch, getState) => {
    dispatch(slice.actions.setHints(state.parts[0].hints));
    dispatch(slice.actions.setAttemptState(state));
    dispatch(slice.actions.setHasMoreHints(state.parts[0].hasMoreHints));
  };

export const selectChoice =
  (
    id: string,
    onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>,
    type: 'single' | 'multiple',
  ): AppThunk =>
  async (dispatch, getState) => {
    // Update local state by adding or removing the id
    if (type === 'single') {
      dispatch(slice.actions.updateChoiceSelectionSingle(id));
    } else if (type === 'multiple') {
      dispatch(slice.actions.updateChoiceSelectionMultiple(id));
    }

    // Post the student response to save it
    // Here we will make a list of the selected ids like { input: [id1, id2, id3].join(' ')}
    // Then in the rule evaluator, we will say
    // `input like id1 && input like id2 && input like id3`
    return onSaveActivity(getState().attemptState.attemptGuid, [
      {
        attemptGuid: getState().attemptState.parts[0].attemptGuid,
        response: { input: selectedChoicesToInput(getState()) },
      },
    ]);
  };
