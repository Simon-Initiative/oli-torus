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
  /**
   * If this attempt has been evaluated, the date of the evaluation, null
   * if this attempt has not been evaluated.
   */
  dateEvaluated: Date | null;

  /**
   * The date that this attempt was submitted, if it has been submitted, null
   * if not.
   */
  dateSubmitted: Date | null;

  /**
   * Score received. Null if this attempt has not been evaluated.
   */
  score: number | null;
  /**
   * Maximum point value that could have been received.
   */
  outOf: number | null;
  /**
   * The student's response.
   */
  response: any;
  /**
   * Feedback received, if this attempt has been evaluated.
   */
  feedback: Feedback | null;
  /**
   * Hints that were requested and received by the student.
   */
  hints: [];
  /**
   * The id of the part that this attempt pertains to.
   */
  partId: string | number;
  /**
   * Whether or not additional attempts exist.
   */
  hasMoreAttempts: boolean;
  /**
   * Whether or not additional hints exist.
   */
  hasMoreHints: boolean;
  /**
   * Any error associated with this attempt.
   */
  error?: string;
}

/**
 * Details the current state of an activity attempt for a student
 * and a specific activity instance.
 */
export interface ActivityState {
  /**
   * Resource id of the activity that this attempt pertains to.
   */
  activityId?: ResourceId;
  /**
   * Unique identifier of this attempt.
   */
  attemptGuid: string;

  /**
   * The orindal number of this attempt, relative to other attempts.
   */
  attemptNumber: number;
  /**
   * If this attempt has been evaluated, the date of the evaluation, null
   * if this attempt has not been evaluated.
   */
  dateEvaluated: Date | null;

  /**
   * The date that this attempt was submitted, if it has been submitted, null
   * if not.
   */
  dateSubmitted: Date | null;

  /**
   * Score received. Null if this attempt has not been evaluated.
   */
  score: number | null;
  /**
   * Maximum point value that could have been received.
   */
  outOf: number | null;
  /**
   * Collection of the part attempt states.
   */
  parts: PartState[];

  /**
   * Whether or not this attempt has additional attempts.
   */
  hasMoreAttempts: boolean;
  /**
   * Whether or not this attempt has additonal hints.
   */
  hasMoreHints: boolean;
  snapshot?: any;
}

/**
 * Defines an option, or choice, within activities such as a
 * multiple choice activity.
 */
export interface Choice extends Identifiable, HasContent {}
/**
 * Helper function to create a choice from simple text.
 */
export const makeChoice: (text: string, id?: string) => Choice = makeContent;
/**
 * Marker interface for an entity that has choices.
 */
export interface HasChoices {
  choices: Choice[];
}

/**
 * Defines a question stem.
 */
export interface Stem extends Identifiable, HasContent {}
/**
 * Marker interface for an entity that has a question stem.
 */
export interface HasStem {
  stem: Stem;
}
/**
 * Marker interface for an entity that has a collection of stems.
 */
export type HasStems = { stems: Stem[] };
/**
 * Helper function to create a stem from a simple string.
 */
export const makeStem: (text: string) => Stem = makeContent;
/**
 * Defines a hint.
 */
export interface Hint extends Identifiable, HasContent {}
/**
 * Marker interface for an entity that has hints.
 */
export type HasHints = HasParts;
/**
 * Helper function to create a hint from simple text.
 */
export const makeHint: (text: string) => Hint = makeContent;
/**
 * Defines feedback entity.
 */
export interface Feedback extends Identifiable, HasContent {}
/**
 * Helper function to create Feedback from simple text.
 */
export const makeFeedback: (text: string) => Feedback = makeContent;

/**
 * A transformation is a client-specified mutation of the activity
 * content model that the server will perform during activity
 * instantiation.
 */
export interface Transformation extends Identifiable {
  path: string;
  operation: Transform;
}
/**
 * Marker interface for an entity that has transformations.
 */
export interface HasTransformations {
  authoring: {
    transformations: Transformation[];
  };
}
/**
 * Helper function to create a transformation.
 * @param path  JSON path of the node within the model to transform
 * @param operation The transformation operation
 * @returns
 */
export const makeTransformation = (path: string, operation: Transform): Transformation => ({
  id: guid(),
  path,
  operation,
});

/**
 * Defines a response.
 */
export interface Response extends Identifiable {
  // see `parser.ex` and `rule.ex`
  /**
   * Rule based match.
   */
  rule: string;
  /**
   * Score to assign if this response matches.
   */
  score: number;
  /**
   * Feedback to assign if this response matches.
   */
  feedback: Feedback;
}

/**
 * Helper function to create a response.
 * @param rule match rule
 * @param score score to assign
 * @param text simple text to formulate a Feedback from
 * @returns
 */
export const makeResponse = (rule: string, score: number, text = ''): Response => ({
  id: guid(),
  rule,
  score,
  feedback: makeFeedback(text),
});

/**
 * Marker interface for an action.
 */
export interface IsAction {
  attempt_guid: string;
  error?: string;
  part_id: string;
}

/**
 * Supported actions.
 */
export type Action = NavigationAction | FeedbackAction | StateUpdateAction | SubmissionAction;

/**
 * An action indicating that the current view should navigate
 * to another view.  Currently not in use.
 */
export interface NavigationAction extends IsAction {
  type: 'NavigationAction';
  to: string;
}

/**
 * An action indicating that feedback should be displayed.
 */
export interface FeedbackAction extends IsAction {
  type: 'FeedbackAction';
  out_of: number;
  score: number;
  feedback: Feedback;
}

/**
 * An action indicating that global user state should be updated.
 * Currently not in use.
 */
export interface StateUpdateAction extends IsAction {
  type: 'StateUpdateAction';
  // eslint-disable-next-line
  update: Object;
}

/**
 * An action indicating that the submission was completed.
 */
export interface SubmissionAction extends IsAction {
  type: 'SubmissionAction';
}

/**
 * Defines an activity part.
 */
export interface Part extends Identifiable {
  responses: Response[];
  hints: Hint[];
  scoringStrategy: ScoringStrategy;
  gradingApproach?: GradingApproach;
  outOf?: null | number;
}

/**
 * Helper function to create a part.
 * @param responses responses to use
 * @param hints hints to use
 * @param id the part id
 * @returns the formulated part
 */
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

/**
 * Marker interface for an entity that has parts.
 */
export interface HasParts {
  authoring: {
    parts: Part[];
  };
}

/**
 * The types of grading, or scoring, supported for a part.
 */
export enum GradingApproach {
  /**
   * Part will be automatically graded by either the client or server.
   */
  'automatic' = 'automatic',
  /**
   * Part requires manual grading by an instructor.
   */
  'manual' = 'manual',
}

/**
 * Strategy to use in calculating a score across a collection of
 * either parts or attempts.
 */
export enum ScoringStrategy {
  'average' = 'average',
  'best' = 'best',
  'most_recent' = 'most_recent',
}

/**
 * Supported transforms.
 */
export enum Transform {
  /**
   * Randomly shuffles a collection of items.
   */
  'shuffle' = 'shuffle',
}

/**
 * Context supplied to a creation function.
 */
export interface CreationContext extends ResourceContext {}

/**
 * @ignore
 */
export interface PartComponentDefinition {
  id: string;
  type: string;
  custom: Record<string, any>;
}

/**
 * Marker interface for an entity that has preview text.
 */
export interface HasPreviewText {
  authoring: {
    previewText: string;
  };
}
/**
 * Helper function to create preview text.
 * @returns
 */
export const makePreviewText = () => '';

/**
 * Defines a mapping of a collection of choices to a response.
 */
export type ChoiceIdsToResponseId = [ChoiceId[], ResponseId];
