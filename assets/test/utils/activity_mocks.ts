import { fromText } from 'components/activities/check_all_that_apply/utils';
import { EvaluationResponse, RequestHintResponse } from 'components/activities/DeliveryElement';
import { Action, ActivityState, PartState } from 'components/activities/types';
import { createFalse } from 'typescript';

const partState: PartState = {
  attemptGuid: 'guid',
  attemptNumber: 1,
  dateEvaluated: null,
  score: null,
  outOf: 1,
  response: null,
  feedback: 'feedback',
  hints: [],
  partId: 1,
  hasMoreAttempts: true,
  hasMoreHints: true,
} as any;

export const attemptState: ActivityState = {
  attemptGuid: 'guid',
  attemptNumber: 1,
  dateEvaluated: null,
  score: null,
  outOf: 1,
  parts: [partState],
  hasMoreAttempts: true,
  hasMoreHints: true,
};

const feedbackAction: Action = {
  type: 'FeedbackAction',
  attempt_guid: '1',
  out_of: 1,
  score: 1,
  feedback: fromText('correct feedback'),
};

const evaluationResponse: EvaluationResponse = {
  type: 'success',
  actions: [feedbackAction],
};

const requestHintResponse: RequestHintResponse = {
  type: 'success',
  hint: fromText('hint'),
  hasMoreHints: false,
};

const onSubmitActivity = jest.fn().mockImplementation(() => Promise.resolve(evaluationResponse));
const onSaveActivity = jest.fn();
const onResetActivity = jest.fn();
const onRequestHint = jest.fn().mockImplementation(() => Promise.resolve(requestHintResponse));
const onSavePart = jest.fn();
const onSubmitPart = jest.fn();
const onResetPart = jest.fn();
const onSubmitEvaluations = jest.fn();

export const defaultDeliveryElementProps = {
  onSaveActivity,
  onSubmitActivity,
  onResetActivity,
  onRequestHint,
  onSavePart,
  onSubmitPart,
  onResetPart,
  onSubmitEvaluations,
  state: attemptState,
  review: false,
  userId: 1,
};
