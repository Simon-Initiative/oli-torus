import { ModelElement } from 'data/content/model/elements/types';
import { ID, Identifiable } from 'data/content/model/other';
import { ResourceContext } from 'data/content/resource';
import { ResourceId } from 'data/types';
import guid from 'utils/guid';
import { PathOperation } from 'utils/pathOperations';
import { Model } from 'data/content/model/elements/factories';

/**
 * Converts a rich text feedback, that may contain inline markup and
 * block-level elements, to text.
 *
 * This function should only be used in contexts where there is a
 * guarantee that the loss of data via this conversion is not a problem.
 *
 * @param feedback rich text capable feedback
 * @returns only the string text found within the feedback
 */
export function feedbackToString(feedback: Feedback): string {
  return contentToString(feedback.content);
}

function contentToString(content: any) {
  return content.reduce((acc: any, e: any) => {
    if (e.text !== undefined) {
      return acc + e.text;
    }
    if (e.children !== undefined) {
      return acc + contentToString(e.children);
    }
    return acc;
  }, '');
}

/**
 * Type for the post undo function.
 */
export type PostUndoable = (undoable: Undoable) => void;

/**
 * Three different modes of activity delivery.
 *
 * `'delivery'` is the standard mode where a student is interacting
 * with a an activity
 * `'review'` mode is when a student is reviewing a previously
 * submitted activity, in a read only mode
 * `'preview'` mode is instructor specific and allows access to
 * responses and hints
 */
export type DeliveryMode = 'delivery' | 'review' | 'preview';

/**
 * Request for a media item from the media library.
 */
export type MediaItemRequest = {
  type: 'MediaItemRequest';
  mimeTypes: string[];
};

/**
 * An Undoable action that an activity defines as a result of some (usually
 * destructive) operation.
 *
 * For example, if a choice is deleted via the user interface of an activity,
 * the activity can create and post an `Undoable` that, if invoked by the
 * page editor, would result in the choice being restored.
 */
export type Undoable = {
  type: 'Undoable';
  description: string;
  operations: PathOperation[];
};

/**
 * Helper function to create an instance of an `Undoable`
 * @param description Description of the undoable
 * @param operations Collection of path operations on the model that implements the undoable
 * @returns an undoable instance
 */
export function makeUndoable(description: string, operations: PathOperation[]): Undoable {
  return {
    type: 'Undoable',
    description,
    operations,
  };
}

/**
 * Alias for the identifier of a choice.
 */
export type ChoiceId = ID;

/**
 * Alias for the identifier of a part.
 */
export type PartId = ID;

/**
 * Alias for the identifier of a response.
 */
export type ResponseId = ID;

/**
 * Rich text definition, an array of `ModelElement` instances.
 */
export type RichText = ModelElement[];

export interface Success {
  type: 'success';
}

/**
 * Marker interface for items that have rich text content.
 */
export interface HasContent {
  content: RichText;
}

/**
 * Helper function to create a content object out of a raw string. Returns
 * the string as a single paragraph within rich text, within the content
 * object.
 * @param text text string
 * @param id optional identifier
 * @returns content
 */
export function makeContent(text: string, id?: string): { id: string; content: RichText } {
  return {
    id: id ? id : guid(),
    content: [Model.p(text)],
  };
}

/**
 * A student submission for an activity.  The `input` attribute can be
 * encoded any way that the activity desires, from a simple string to a
 * complex JSON tree.
 */
export interface StudentResponse {
  input: any;
}

export type ModeSpecification = {
  element: string;
  entry: string;
};

/**
 * Type type allows the submission of a response for a specific
 * part of an activity.
 */
export type PartResponse = {
  attemptGuid: string;
  response: StudentResponse;
};

/**
 * Allows submission of a client-side evaluation for an activity
 * submission.
 */
export type ClientEvaluation = {
  attemptGuid: string;
  score: number | null;
  outOf: number | null;
  response: any;
  feedback: any;
};

/**
 * Structure of an activity manifest.
 *
 * The `id` field must be unique amongst all activities registered in
 * a Torus instance.  The format for the `id` field is `<namespace>_<descriptor>`
 * where `<namespace>`  is the designated namespace for this family of activities
 * and `<descriptor>` is a terse description of this specific activity.  Examples
 * include: `oli_multiple_choice`, `example_tf`.
 *
 * The `friendlyName` attribute is a short, human readable string that the UX within
 * Torus will display to students, instructors and authors in various contexts. Words
 * within it should be space separated and capitalized.  For example: "Multiple Choice"
 *
 * The `descriptions` attribute is a slightly longer human readable description of the
 * activity.  For example, "A traditional multiple choice question with one correct answer"
 *
 * `delivery` and `authoring` attributes specify the element tag names that the activity
 * is implemented within.
 */
export type Manifest = {
  id: ID;
  friendlyName: string;
  description: string;
  delivery: ModeSpecification;
  authoring: ModeSpecification;
};

/**
 * An extendable activity model schema.
 */
export interface ActivityModelSchema {
  resourceId?: number;
  authoring?: any;
  content?: any;
  activityType?: any;
  id?: string; // maybe slug
}

/**
 * Representation of a student's current state for a specific part of
 * an activity.
 */
export interface PartState {
  /**
   * The unique identifier of this part attempt.
   */
  attemptGuid: string;
  /**
   * The number of this attempt.
   */
  attemptNumber: number;
  dateEvaluated: Date | null;
  dateSubmitted: Date | null;
  score: number | null;
  outOf: number | null;
  response: any;
  feedback: Feedback | null;
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
  dateSubmitted: Date | null;
  score: number | null;
  outOf: number | null;
  parts: PartState[];
  hasMoreAttempts: boolean;
  hasMoreHints: boolean;
  snapshot?: any;
}

export interface Choice extends Identifiable, HasContent {}
export const makeChoice: (text: string, id?: string) => Choice = makeContent;
export interface HasChoices {
  choices: Choice[];
}

export interface Stem extends Identifiable, HasContent {}
export interface HasStem {
  stem: Stem;
}
export type HasStems = { stems: Stem[] };
export const makeStem: (text: string) => Stem = makeContent;
export interface Hint extends Identifiable, HasContent {}
export type HasHints = HasParts;
export const makeHint: (text: string) => Hint = makeContent;
export interface Feedback extends Identifiable, HasContent {}
export const makeFeedback: (text: string) => Feedback = makeContent;
export interface Transformation extends Identifiable {
  path: string;
  operation: Transform;
}
export interface HasTransformations {
  authoring: {
    transformations: Transformation[];
  };
}

export const makeTransformation = (path: string, operation: Transform): Transformation => ({
  id: guid(),
  path,
  operation,
});

export interface Response extends Identifiable {
  // see `parser.ex` and `rule.ex`
  rule: string;
  // `score >= 0` indicates the feedback corresponds to a correct choice
  score: number;
  feedback: Feedback;
}
export const makeResponse = (rule: string, score: number, text = ''): Response => ({
  id: guid(),
  rule,
  score,
  feedback: makeFeedback(text),
});

export interface IsAction {
  attempt_guid: string;
  error?: string;
  part_id: string;
}

export type Action = NavigationAction | FeedbackAction | StateUpdateAction | SubmissionAction;

export interface NavigationAction extends IsAction {
  type: 'NavigationAction';
  to: string;
}

export interface FeedbackAction extends IsAction {
  type: 'FeedbackAction';
  out_of: number;
  score: number;
  feedback: Feedback;
}

export interface StateUpdateAction extends IsAction {
  type: 'StateUpdateAction';
  // eslint-disable-next-line
  update: Object;
}

export interface SubmissionAction extends IsAction {
  type: 'SubmissionAction';
}

export interface Part extends Identifiable {
  responses: Response[];
  hints: Hint[];
  scoringStrategy: ScoringStrategy;
  gradingApproach?: GradingApproach;
  outOf?: null | number;
}

export const makePart = (
  responses: Response[],
  // By default, parts have 3 hints (deer in headlights, cognitive, bottom out)
  // Multiinput activity parts start with just one hint
  hints = [makeHint(''), makeHint(''), makeHint('')],
  id?: ID,
): Part => ({
  id: id ? id : guid(),
  gradingApproach: GradingApproach.automatic,
  outOf: null,
  scoringStrategy: ScoringStrategy.average,
  responses,
  hints,
});

export interface HasParts {
  authoring: {
    parts: Part[];
  };
}

export enum GradingApproach {
  'automatic' = 'automatic',
  'manual' = 'manual',
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

export enum Transform {
  'shuffle' = 'shuffle',
}

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
