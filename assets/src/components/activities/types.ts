import { create, ID, Identifiable, ModelElement, Selection } from 'data/content/model';
import { ResourceContext } from 'data/content/resource';
import { ResourceId } from 'data/types';
import { UndoOperation } from 'utils/undo';
import guid from 'utils/guid';

export type PostUndoable = (undoable: Undoable) => void;

export type MediaItemRequest = {
  type: 'MediaItemRequest',
  mimeTypes: string[]
}

export type Undoable = {
  type: 'Undoable';
  description: string;
  operations: UndoOperation[];
}

export function makeUndoable(description: string, operations: UndoOperation[]) : Undoable {
  return {
    type: 'Undoable',
    description,
    operations
  };
}

export type ChoiceId = ID;
export type ResponseId = ID;

export type RichText = {
  model: ModelElement[];
  selection: Selection;
};

export interface Success {
  type: 'success';
}

export interface HasContent {
  content: RichText;
}
export function makeContent(text: string): { id: string; content: RichText } {
  return {
    id: guid() + '',
    content: {
      model: [
        create({
          type: 'p',
          children: [{ text }],
          id: guid() + '',
        }),
      ],
      selection: null,
    },
  };
}

export interface StudentResponse {
  input: any;
}

export type ModeSpecification = {
  element: string;
  entry: string;
};

export type PartResponse = {
  attemptGuid: string;
  response: StudentResponse;
};

export type ClientEvaluation = {
  attemptGuid: string;
  score: number | null;
  outOf: number | null;
  response: any;
  feedback: any;
};

export type Manifest = {
  id: ID;
  friendlyName: string;
  description: string;
  delivery: ModeSpecification;
  authoring: ModeSpecification;
};

export interface ActivityModelSchema {
  resourceId?: number;
  authoring?: any;
  content?: any;
  activityType?: any;
  id?: string; // maybe slug
}

export interface PartState {
  attemptGuid: string;
  attemptNumber: number;
  dateEvaluated: Date | null;
  score: number | null;
  outOf: number | null;
  response: any;
  feedback: any;
  hints: [];
  partId: string | number;
  hasMoreAttempts: boolean;
  hasMoreHints: boolean;
  error?: string;
}

export interface ActivityState {
  activityId?: ResourceId;
  attemptGuid: string;
  attemptNumber: number;
  dateEvaluated: Date | null;
  score: number | null;
  outOf: number | null;
  parts: PartState[];
  hasMoreAttempts: boolean;
  hasMoreHints: boolean;
  snapshot?: any;
}

export interface Choice extends Identifiable, HasContent {}
export const makeChoice: (text: string) => Choice = makeContent;
export interface HasChoices {
  choices: Choice[];
}

export interface Stem extends Identifiable, HasContent {}
export interface HasStem {
  stem: Stem;
}
export const makeStem: (text: string) => Stem = makeContent;
export interface Hint extends Identifiable, HasContent {}
export type HasHints = HasParts;
export const makeHint: (text: string) => Hint = makeContent;
export interface Feedback extends Identifiable, HasContent {}
export const makeFeedback: (text: string) => Feedback = makeContent;
export interface Transformation extends Identifiable {
  path: string;
  operation: Operation;
}
export interface HasTransformations {
  authoring: {
    transformations: Transformation[];
  };
}

export const makeTransformation = (path: string, operation: Operation): Transformation => ({
  id: guid(),
  path: 'choices',
  operation,
});

export interface Response extends Identifiable {
  // see `parser.ex` and `rule.ex`
  rule: string;

  // `score >= 0` indicates the feedback corresponds to a correct choice
  score: number;

  feedback: Feedback;
}
export const makeResponse = (rule: string, score: number, text: ''): Response => ({
  id: guid(),
  rule,
  score,
  feedback: makeFeedback(text),
});

export interface ConditionalOutcome extends Identifiable {
  // eslint-disable-next-line
  rule: Object;
  actions: ActionDesc[];
}

export interface IsAction {
  attempt_guid: string;
  error?: string;
}

export type Action = NavigationAction | FeedbackAction | StateUpdateAction;
export type ActionDesc = NavigationActionDesc | FeedbackActionDesc | StateUpdateActionDesc;

export interface FeedbackActionCore {
  score: number;
  feedback: Feedback;
}

export interface NavigationActionCore {
  to: string;
}

export interface StateUpdateActionCore {
  // eslint-disable-next-line
  update: Object;
}

export interface NavigationActionDesc extends Identifiable, NavigationActionCore {
  type: 'NavigationActionDesc';
}

export interface NavigationAction extends NavigationActionCore, IsAction {
  type: 'NavigationAction';
}

export interface FeedbackActionDesc extends Identifiable, FeedbackActionCore {
  type: 'FeedbackActionDesc';
}

export interface FeedbackAction extends FeedbackActionCore, IsAction {
  type: 'FeedbackAction';
  out_of: number;
}

export interface StateUpdateActionDesc extends Identifiable, StateUpdateActionCore {
  type: 'StateUpdateActionDesc';
}

export interface StateUpdateAction extends StateUpdateActionCore, IsAction {
  type: 'StateUpdateAction';
}

export interface Part extends Identifiable {
  responses: Response[];
  outcomes?: ConditionalOutcome[];
  hints: Hint[];
  scoringStrategy: ScoringStrategy;
}
export interface HasParts {
  authoring: {
    parts: Part[];
  };
}

export enum ScoringStrategy {
  'average' = 'average',
  'best' = 'best',
  'most_recent' = 'most_recent',
}

export enum EvaluationStrategy {
  'regex' = 'regex',
  'numeric' = 'numeric',
  'none' = 'none',
}

export enum Operation {
  'shuffle' = 'shuffle',
}
// eslint-disable-next-line
export interface CreationContext extends ResourceContext {}

export interface PartComponentDefinition {
  id: string;
  type: string;
  custom: Record<string, any>;
}

export interface HasPreviewText {
  authoring: {
    previewText: string;
  };
}
export const makePreviewText = () => '';

export type ChoiceIdsToResponseId = [ChoiceId[], ResponseId];
