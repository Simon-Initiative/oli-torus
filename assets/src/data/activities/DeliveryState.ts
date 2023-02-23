import { AnyAction, createSlice, Dispatch, PayloadAction, ThunkAction } from '@reduxjs/toolkit';
import {
  EvaluationResponse,
  RequestHintResponse,
  ResetActivityResponse,
  PartActivityResponse,
  ActivityContext,
} from 'components/activities/DeliveryElement';
import {
  ActivityState,
  FeedbackAction,
  SubmissionAction,
  Hint,
  PartId,
  PartResponse,
  PartState,
  StudentResponse,
  Success,
  FileMetaData,
} from 'components/activities/types';
import { updatePaginationState } from 'data/persistence/pagination';
import * as Events from 'data/events';
import { studentInputToString } from 'data/activities/utils';
import { WritableDraft } from 'immer/dist/internal';
import { ActivityModelSchema } from 'components/activities/types';
import { Maybe } from 'tsmonad';
import { initialPartInputs, isCorrect } from 'data/activities/utils';

export type AppThunk<ReturnType = void> = ThunkAction<
  ReturnType,
  ActivityDeliveryState,
  unknown,
  AnyAction
>;
export type StudentInput = string[];
export type PartInputs = Record<PartId, StudentInput>;

export interface ActivityDeliveryState {
  model: ActivityModelSchema;
  activityContext: ActivityContext;
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
        action.type === 'FeedbackAction' && action.part_id === part.partId,
    ) as FeedbackAction | undefined;
    if (!feedbackAction) return part;
    return Object.assign(part, {
      score: feedbackAction.score,
      outOf: feedbackAction.out_of,
      feedback: feedbackAction.feedback,
      explanation: feedbackAction.explanation,
      error: feedbackAction.error,
      dateEvaluated: new Date(),
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

function handleAutomationInResponse(
  state: WritableDraft<ActivityDeliveryState>,
  action: PayloadAction<EvaluationResponse>,
) {
  const toShow: number[] = action.payload.actions
    .filter((a: FeedbackAction) => a.show_page !== null)
    .map((a: FeedbackAction) => a.show_page) as number[];

  if (toShow.length > 0) {
    const forId = state.attemptState.groupId as string;

    toShow.forEach((index: number) =>
      Events.dispatch(
        Events.Registry.ShowContentPage,
        Events.makeShowContentPage({ forId, index }),
      ),
    );

    updatePaginationState(
      state.activityContext.sectionSlug,
      state.activityContext.pageAttemptGuid,
      forId,
      toShow,
    );
  }
}

export const activityDeliverySlice = createSlice({
  name: 'ActivityDelivery',
  initialState: {} as ActivityDeliveryState,
  reducers: {
    activitySubmissionReceived(state, action: PayloadAction<EvaluationResponse>) {
      if (action.payload.actions.length > 0) {
        const { score, out_of } = calculateNewScore(action);

        handleAutomationInResponse(state, action);

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
    partSubmissionReceived(state, action: PayloadAction<EvaluationResponse>) {
      if (action.payload.actions.length > 0) {
        const parts = updatePartsStates(state, action);

        handleAutomationInResponse(state, action);

        state.attemptState = {
          ...state.attemptState,
          parts,
          dateEvaluated: parts.every((p) => p.dateEvaluated !== null) ? new Date() : null,
        };
      }
    },
    partResetRecieved(state, action: PayloadAction<PartActivityResponse>) {
      const parts = state.attemptState.parts.map((p: WritableDraft<PartState>) => {
        if (action.payload.attemptState.partId === p.partId) {
          return action.payload.attemptState;
        }
        return p;
      });
      state.attemptState = {
        ...state.attemptState,
        parts,
      };
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
    updatePartState(state, action: PayloadAction<{ partId: PartId; response: any }>) {
      Maybe.maybe(state.partState[action.payload.partId]).lift(
        (partState) => (partState.studentInput = action.payload.response),
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
    updateModel(state, action: PayloadAction<ActivityModelSchema>) {
      state.model = action.payload;
    },
    updateActivityContext(state, action: PayloadAction<ActivityContext>) {
      state.activityContext = action.payload;
    },
    hideHintsForPart(state, action: PayloadAction<PartId>) {
      Maybe.maybe(state.partState[action.payload]).lift((partState) => (partState.hintsShown = []));
    },
  },
});
const slice = activityDeliverySlice;

export const savePart =
  (
    partId: PartId,
    response: any,
    onSave: (
      attemptGuid: string,
      partAttemptGuid: string,
      payload: StudentResponse,
    ) => Promise<Success>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const attemptGuid = getState().attemptState.parts.find(
      (part) => String(part.partId) === partId,
    )?.attemptGuid;
    if (!attemptGuid) return;

    await onSave(getState().attemptState.attemptGuid, attemptGuid, response);
    const files = (response as any).files;
    dispatch(slice.actions.updatePartState({ partId, response: files }));
  };

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
  selectAttemptState(state).dateEvaluated !== null;

export const isSubmitted = (state: ActivityDeliveryState) =>
  selectAttemptState(state).dateSubmitted !== null;

export const resetAndRequestHintAction =
  (
    partId: PartId,
    onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>,
    onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>,
    partInputs?: PartInputs,
  ): AppThunk =>
  async (dispatch, getState) => {
    await dispatch(resetAction(onResetActivity, partInputs));
    await dispatch(requestHint(partId, onRequestHint));
  };

export const resetAction =
  (
    onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>,
    partInputs?: PartInputs,
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onResetActivity(getState().attemptState.attemptGuid);
    partInputs && dispatch(slice.actions.setPartInputs(partInputs));
    dispatch(slice.actions.updateModel(response.model));
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

export const getPartResponses = (activityState: ActivityDeliveryState) =>
  activityState.attemptState.parts.map((partState) => ({
    attemptGuid: partState.attemptGuid,
    response: {
      input: studentInputToString(
        Maybe.maybe(activityState.partState[String(partState.partId)]?.studentInput).valueOr(['']),
      ),
    },
  }));

export const submit =
  (
    onSubmitActivity: (
      attemptGuid: string,
      partResponses: PartResponse[],
    ) => Promise<EvaluationResponse>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const activityState = getState();
    const response = await onSubmitActivity(
      activityState.attemptState.attemptGuid,
      getPartResponses(activityState),
    );
    dispatch(slice.actions.activitySubmissionReceived(response));
  };

export const submitPart =
  (
    attemptGuid: string,
    partAttemptGuid: string,
    studentResponse: StudentResponse,
    onSubmitPart: (
      attemptGuid: string,
      partAttemptGuid: string,
      studentResponse: StudentResponse,
    ) => Promise<EvaluationResponse>,
  ): AppThunk =>
  async (dispatch, _getState) => {
    const response = await onSubmitPart(attemptGuid, partAttemptGuid, studentResponse);
    dispatch(slice.actions.partSubmissionReceived(response));
  };

export const resetAndSavePart =
  (
    attemptGuid: string,
    partAttemptGuid: string,
    partId: string,
    response: any,
    onSave: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>,
    onResetPart: (attemptGuid: string, partAttemptGuid: string) => Promise<PartActivityResponse>,
  ): AppThunk =>
  async (dispatch, _getState) => {
    const partActivityResponse = await onResetPart(attemptGuid, partAttemptGuid);
    dispatch(slice.actions.partResetRecieved(partActivityResponse));
    const partResponses: PartResponse[] = [
      { attemptGuid: partActivityResponse.attemptState.attemptGuid, response },
    ];
    dispatch(
      activityDeliverySlice.actions.setStudentInputForPart({
        partId: partId,
        studentInput: [response.input],
      }),
    );
    onSave(attemptGuid, partResponses);
  };

export const resetAndSubmitPart =
  (
    attemptGuid: string,
    partAttemptGuid: string,
    studentResponse: StudentResponse,
    onResetPart: (attemptGuid: string, partAttemptGuid: string) => Promise<PartActivityResponse>,
    onSubmitPart: (
      attemptGuid: string,
      partAttemptGuid: string,
      studentResponse: StudentResponse,
    ) => Promise<EvaluationResponse>,
  ): AppThunk =>
  async (dispatch, _getState) => {
    const partActivityResponse = await onResetPart(attemptGuid, partAttemptGuid);
    dispatch(slice.actions.partResetRecieved(partActivityResponse));
    const response = await onSubmitPart(
      attemptGuid,
      partActivityResponse.attemptState.attemptGuid,
      studentResponse,
    );
    dispatch(slice.actions.partSubmissionReceived(response));
  };

export const resetPart =
  (
    attemptGuid: string,
    partAttemptGuid: string,
    onResetPart: (attemptGuid: string, partAttemptGuid: string) => Promise<PartActivityResponse>,
  ): AppThunk =>
  async (dispatch, _getState) => {
    const partActivityResponse = await onResetPart(attemptGuid, partAttemptGuid);
    dispatch(slice.actions.partResetRecieved(partActivityResponse));
  };

export const resetAndSubmitActivity =
  (
    attemptGuid: string,
    responses: StudentResponse[],
    onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>,
    onSubmitActivity: (
      attemptGuid: string,
      partResponses: PartResponse[],
    ) => Promise<EvaluationResponse>,
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onResetActivity(attemptGuid);
    dispatch(slice.actions.updateModel(response.model));
    dispatch(slice.actions.setAttemptState(response.attemptState));
    getState().attemptState.parts.forEach((partState) =>
      dispatch(
        slice.actions.setHasMoreHintsForPart({
          partId: String(partState.partId),
          hasMoreHints: partState.hasMoreHints,
        }),
      ),
    );

    const partResponses = [];
    for (let i = 0; i < responses.length; i++) {
      partResponses.push({
        attemptGuid: response.attemptState.parts[i].attemptGuid,
        response: responses[i],
      } as PartResponse);
    }

    const submitResponse = await onSubmitActivity(response.attemptState.attemptGuid, partResponses);
    dispatch(slice.actions.activitySubmissionReceived(submitResponse));
  };

export const submitFiles =
  (
    onSubmitActivity: (
      attemptGuid: string,
      partResponses: PartResponse[],
    ) => Promise<EvaluationResponse>,
    getFilesFromState: (state: ActivityDeliveryState) => FileMetaData[],
  ): AppThunk =>
  async (dispatch, getState) => {
    const response = await onSubmitActivity(
      getState().attemptState.attemptGuid,
      getState().attemptState.parts.map((partState) => ({
        attemptGuid: partState.attemptGuid,
        response: {
          files: getFilesFromState(getState()),
          input: [''],
        },
      })),
    );
    dispatch(slice.actions.activitySubmissionReceived(response));
  };

export const initializeState =
  (
    state: ActivityState,
    initialPartInputs: PartInputs,
    model: ActivityModelSchema,
    activityContext: ActivityContext,
  ): AppThunk =>
  async (dispatch, _getState) => {
    dispatch(slice.actions.initializePartState(state));
    dispatch(slice.actions.updateModel(model));
    dispatch(slice.actions.updateActivityContext(activityContext));
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

export const listenForParentSurveySubmit = (
  surveyId: string | null,
  dispatch: Dispatch<any>,
  onSubmitActivity: (
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => Promise<EvaluationResponse>,
) =>
  Maybe.maybe(surveyId).lift((surveyId) =>
    // listen for survey submit events if the delivery element is in a survey

    document.addEventListener(Events.Registry.SurveySubmit, (e) => {
      // check if this activity belongs to the survey being submitted
      if (e.detail.id === surveyId) {
        dispatch(submit(onSubmitActivity));
      }
    }),
  );

export const listenForParentSurveyReset = (
  surveyId: string | null,
  dispatch: Dispatch<any>,
  onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>,
  partInputs?: PartInputs,
) =>
  Maybe.maybe(surveyId).lift((surveyId) =>
    // listen for survey submit events if the delivery element is in a survey
    document.addEventListener(Events.Registry.SurveyReset, (e) => {
      // check if this activity belongs to the survey being reset
      if (e.detail.id === surveyId) {
        dispatch(resetAction(onResetActivity, partInputs));
      }
    }),
  );

export const listenForReviewAttemptChange = (
  model: ActivityModelSchema,
  activityId: number,
  dispatch: Dispatch<any>,
  context: ActivityContext,
) => {
  document.addEventListener(Events.Registry.ReviewModeAttemptChange, (e) => {
    // check if this activity is having its attempt changed
    if (e.detail.forId === activityId) {
      dispatch(
        initializeState(
          e.detail.state as any,
          initialPartInputs(model, e.detail.state as any),
          e.detail.model as any,
          context,
        ),
      );
    }
  });
};
