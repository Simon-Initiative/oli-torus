import { AuthoringElementProps } from 'components/activities/AuthoringElement';
import { EvaluationResponse, RequestHintResponse } from 'components/activities/DeliveryElement';
import {
  Action,
  ActivityModelSchema,
  ActivityState,
  DeliveryMode,
  PartState,
  makeFeedback,
  makeHint,
} from 'components/activities/types';

const partState: PartState = {
  attemptGuid: 'guid',
  attemptNumber: 1,
  dateEvaluated: null,
  dateSubmitted: null,
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
  dateSubmitted: null,
  score: null,
  outOf: 1,
  parts: [partState],
  hasMoreAttempts: true,
  hasMoreHints: true,
  groupId: null,
};

const feedbackAction: Action = {
  type: 'FeedbackAction',
  attempt_guid: '1',
  part_id: '1',
  out_of: 1,
  score: 1,
  show_page: null,
  feedback: makeFeedback('correct feedback'),
  explanation: null,
};

const evaluationResponse: EvaluationResponse = {
  type: 'success',
  actions: [feedbackAction],
};

const requestHintResponse: RequestHintResponse = {
  type: 'success',
  hint: makeHint('hint'),
  hasMoreHints: false,
};

const onSubmitActivity = jest.fn().mockImplementation(() => Promise.resolve(evaluationResponse));
const onSaveActivity = jest.fn().mockImplementation(() => Promise.resolve({ type: 'success' }));
const onResetActivity = jest.fn().mockImplementation(() => Promise.resolve({ type: 'success' }));
const onRequestHint = jest.fn().mockImplementation(() => Promise.resolve(requestHintResponse));
const onSavePart = jest.fn().mockImplementation(() => Promise.resolve({ type: 'success' }));
const onSubmitPart = jest.fn().mockImplementation(() => Promise.resolve({ type: 'success' }));
const onResetPart = jest.fn().mockImplementation(() => Promise.resolve({ type: 'success' }));
const onSubmitEvaluations = jest
  .fn()
  .mockImplementation(() => Promise.resolve({ type: 'success' }));

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
  mode: 'delivery' as DeliveryMode,
  userId: 1,
};

export const defaultAuthoringElementProps = <T extends ActivityModelSchema>(
  initialModel: T,
): AuthoringElementProps<T> => {
  const model = initialModel;
  return {
    projectSlug: '',
    authoringContext: { contentBreaksExist: false },
    editMode: true,
    model,
    onPostUndoable: jest.fn(),
    onRequestMedia: jest.fn(),
    onEdit: (newModel) => Object.assign(model as any, newModel),
  };
};
