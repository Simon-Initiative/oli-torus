import { AnyAction, createSlice, PayloadAction, ThunkAction } from '@reduxjs/toolkit';
import {
  EvaluationResponse,
  RequestHintResponse,
  ResetActivityResponse,
} from 'components/activities/DeliveryElement';
import {
  ActivityState,
  FeedbackAction,
  SubmissionAction,
  Hint,
  PartId,
  PartResponse,
  PartState,
  Success,
} from 'components/activities/types';
import { studentInputToString } from 'data/activities/utils';
import { WritableDraft } from 'immer/dist/internal';
import { Maybe } from 'tsmonad';

export type AppThunk<ReturnType = void> = ThunkAction<
  ReturnType,
  ActivityDeliveryState,
  unknown,
  AnyAction
>;
export type StudentInput = string[];
export type PartInputs = Record<PartId, StudentInput>;

export interface ActivityDeliveryState {
  attemptState: ActivityState;
  partState: Record<
    PartId,
    {
      studentInput: StudentInput;
      hintsShown: Hint[];
      hasMoreHints: boolean;
    }
  >;
}

// From the results of a potentially multi-part submission, calculate the overall
// score and out of for the activity.  If at least one action is not a FeedbackAction,
// the activity is not fully evaluated, thus the score and out of must be null
function calculateNewScore(action: PayloadAction<EvaluationResponse>) {
  if (!action.payload.actions.every((action) => action.type === 'FeedbackAction')) {
    return { score: null, out_of: null };
  }

  return action.payload.actions.reduce(
    (acc, action: FeedbackAction | SubmissionAction) => {
      if (action.type === 'FeedbackAction') {
        return {
          score: acc.score + action.score,
          out_of: acc.out_of + action.out_of,
        };
      }
      return acc;
    },
    {
      score: 0,
      out_of: 0,
    },
  );
}

function updatePartsStates(
  state: WritableDraft<ActivityDeliveryState>,
  action: PayloadAction<EvaluationResponse>,
) {
  return state.attemptState.parts.map((part) => {
    const feedbackAction = action.payload.actions.find(
      (action: FeedbackAction | SubmissionAction) =>
        action.type === 'FeedbackAction' && action.attempt_guid === part.attemptGuid,
    ) as FeedbackAction | undefined;
    if (!feedbackAction) return part;
    return Object.assign(part, {
      score: feedbackAction.score,
      outOf: feedbackAction.out_of,
      feedback: feedbackAction.feedback,
      error: feedbackAction.error,
    } as Partial<PartState>);
  });
}

// The attempt date evaluated must be set to now if and only if a
// non null score has been calculated
function determineDateEvaluated(score: number | null) {
  if (score === null) {
    return null;
  }
  return new Date();
}

// The attempt submission need must be set to now if either the attempt
// has been submitted+evaluated (i.e. a non-null score has been calculated) or
// at least one part evaluation resulted in a SubmissionAction
function determineDateSubmitted(score: number | null, action: PayloadAction<EvaluationResponse>) {
  if (
    score !== null ||
    action.payload.actions.some((action) => action.type === 'SubmissionAction')
  ) {
    return new Date();
  }
  return null;
}

export const activityDeliverySlice = createSlice({
  name: 'ActivityDelivery',
  initialState: {} as ActivityDeliveryState,
  reducers: {
    activitySubmissionReceived(state, action: PayloadAction<EvaluationResponse>) {
      if (action.payload.actions.length > 0) {
        const { score, out_of } = calculateNewScore(action);

        state.attemptState = {
          ...state.attemptState,
          score,
          dateEvaluated: determineDateEvaluated(score),
          dateSubmitted: determineDateSubmitted(score, action),
          outOf: out_of,
          parts: updatePartsStates(state, action),
        };
      }
    },
    initializePartState(state, action: PayloadAction<ActivityState>) {
      state.partState = action.payload.parts.reduce((acc, partState) => {
        acc[String(partState.partId)] = { studentInput: [], hintsShown: [], hasMoreHints: false };
        return acc;
      }, {} as ActivityDeliveryState['partState']);
    },
    setPartInputs(state, action: PayloadAction<PartInputs>) {
      Object.entries(action.payload).forEach(([partId, studentInput]) =>
        Maybe.maybe(state.partState[partId]).lift(
          (partState) => (partState.studentInput = studentInput),
        ),
      );
    },
    setStudentInputForPart(
      state,
      action: PayloadAction<{ partId: PartId; studentInput: StudentInput }>,
    ) {
      Maybe.maybe(state.partState[action.payload.partId]).lift(
        (partState) => (partState.studentInput = action.payload.studentInput),
      );
    },
    setAttemptState(state, action: PayloadAction<ActivityState>) {
      state.attemptState = action.payload;
    },
    updateChoiceSelectionMultiple(
      state,
      action: PayloadAction<{ partId: PartId; selection: string }>,
    ) {
      const { partId, selection } = action.payload;
      Maybe.maybe(state.partState[partId]).lift(
        (partState) =>
          (partState.studentInput = partState.studentInput.find(
            (choiceId) => choiceId === selection,
          )
            ? partState.studentInput.filter((id) => id !== selection)
            : partState.studentInput.concat(selection)),
      );
    },
    setHintsShownForPart(state, action: PayloadAction<{ partId: PartId; hintsShown: Hint[] }>) {
      Maybe.maybe(state.partState[action.payload.partId]).lift(
        (partState) => (partState.hintsShown = action.payload.hintsShown),
      );
    },
    showHintForPart(state, action: PayloadAction<{ partId: PartId; hint: Hint }>) {
      Maybe.maybe(state.partState[action.payload.partId]).lift((partState) =>
        partState.hintsShown.push(action.payload.hint),
      );
    },
    setHasMoreHintsForPart(
      state,
      action: PayloadAction<{ partId: PartId; hasMoreHints: boolean }>,
    ) {
      Maybe.maybe(state.partState[action.payload.partId]).lift(
        (partState) => (partState.hasMoreHints = action.payload.hasMoreHints),
      );
    },
    hideAllHints(state) {
      Object.values(state.partState).forEach((partState) => (partState.hintsShown = []));
    },
    hideHintsForPart(state, action: PayloadAction<PartId>) {
      Maybe.maybe(state.partState[action.payload]).lift((partState) => (partState.hintsShown = []));
    },
  },
});
const slice = activityDeliverySlice;

export const requestHint =
  (
    partId: PartId,
    onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const attemptGuid = getState().attemptState.parts.find(
      (part) => String(part.partId) === partId,
    )?.attemptGuid;
    if (!attemptGuid) return;

    const response = await onRequestHint(getState().attemptState.attemptGuid, attemptGuid);
    Maybe.maybe(response.hint).lift((hint) =>
      dispatch(slice.actions.showHintForPart({ partId, hint })),
    );
    dispatch(slice.actions.setHasMoreHintsForPart({ partId, hasMoreHints: response.hasMoreHints }));
  };

export const selectAttemptState = (state: ActivityDeliveryState) => state.attemptState;
export const isEvaluated = (state: ActivityDeliveryState) =>
  selectAttemptState(state).score !== null;

export const isSubmitted = (state: ActivityDeliveryState) =>
  selectAttemptState(state).dateEvaluated === null &&
  selectAttemptState(state).dateSubmitted !== null;

export const resetAction =
  (
    onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>,
    partInputs: PartInputs,
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onResetActivity(getState().attemptState.attemptGuid);
    dispatch(slice.actions.setPartInputs(partInputs));
    dispatch(slice.actions.hideAllHints());
    dispatch(slice.actions.setAttemptState(response.attemptState));
    getState().attemptState.parts.forEach((partState) =>
      dispatch(
        slice.actions.setHasMoreHintsForPart({
          partId: String(partState.partId),
          hasMoreHints: partState.hasMoreHints,
        }),
      ),
    );
  };

export const submit =
  (
    onSubmitActivity: (
      attemptGuid: string,
      partResponses: PartResponse[],
    ) => Promise<EvaluationResponse>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onSubmitActivity(
      getState().attemptState.attemptGuid,
      getState().attemptState.parts.map((partState) => ({
        attemptGuid: partState.attemptGuid,
        response: {
          input: studentInputToString(
            Maybe.maybe(getState().partState[String(partState.partId)]?.studentInput).valueOr(['']),
          ),
        },
      })),
    );
    dispatch(slice.actions.activitySubmissionReceived(response));
  };

export const initializeState =
  (state: ActivityState, initialPartInputs: PartInputs): AppThunk =>
  async (dispatch, _getState) => {
    dispatch(slice.actions.initializePartState(state));
    state.parts.forEach((partState) => {
      dispatch(
        slice.actions.setHintsShownForPart({
          partId: String(partState.partId),
          hintsShown: partState.hints,
        }),
      );
      dispatch(
        slice.actions.setHasMoreHintsForPart({
          partId: String(partState.partId),
          hasMoreHints: partState.hasMoreHints,
        }),
      );
    });
    dispatch(slice.actions.setAttemptState(state));
    dispatch(slice.actions.setPartInputs(initialPartInputs));
  };

export const setSelection =
  (
    partId: PartId,
    selection: string,
    onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>,
    type: 'single' | 'multiple',
  ): AppThunk =>
  async (dispatch, getState) => {
    const attemptGuid = getState().attemptState.parts.find(
      (part) => String(part.partId) === partId,
    )?.attemptGuid;
    if (!attemptGuid) return;

    // Update local state by adding or removing the id
    if (type === 'single') {
      dispatch(slice.actions.setStudentInputForPart({ partId, studentInput: [selection] }));
    } else if (type === 'multiple') {
      dispatch(slice.actions.updateChoiceSelectionMultiple({ partId, selection }));
    }

    // Post the student response to save it
    // Here we will make a list of the selected ids like { input: [id1, id2, id3].join(' ')}
    // Then in the rule evaluator, we will say
    // `input like id1 && input like id2 && input like id3`
    const newSelection = getState().partState[partId]?.studentInput;
    if (!newSelection) return;

    return onSaveActivity(getState().attemptState.attemptGuid, [
      {
        attemptGuid,
        response: { input: studentInputToString(newSelection) },
      },
    ]);
  };
