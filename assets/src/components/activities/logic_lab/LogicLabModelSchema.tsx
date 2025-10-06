/*
  Models for Torus LogicLab activity data and data exchange.
*/
import { ActivityModelSchema, Feedback, Part, Transformation } from '../types';

// Typing and type checking for existence of variables in a context.
type ContextVariables = { variables: Record<string, string> };
function contextHasVariables(ctx: ContextVariables | unknown): ctx is ContextVariables {
  return !!ctx && ctx instanceof Object && 'variables' in ctx;
}
/**
 * Extract the LogicLab url from a context with null safety.
 * @param context deploy context or activity edit context
 * @returns url to use as a base for logiclab service calls
 */
export function getLabServer(context: ContextVariables | unknown): string {
  if (contextHasVariables(context)) {
    const variables = context.variables;
    if ('ACTIVITY_LOGICLAB_URL' in variables && variables.ACTIVITY_LOGICLAB_URL) {
      return variables.ACTIVITY_LOGICLAB_URL;
    }
  }
  throw new ReferenceError('ACTIVITY_LOGICLAB_URL is not set.');
}

export interface LogicLabModelSchema extends ActivityModelSchema {
  activity: string; // Have to set at higher level as not all information in authoring.parts (eg) targets, are available in all contexts
  context?: ContextInfo;
  authoring: {
    version: 1;
    parts: Part[]; // required in use
    transformations: Transformation[];
    previewText: string;
  };
  feedback: Feedback[];
}

// info saved from Creation Context
export interface ContextInfo {
  title: string;
}

type LabScore = {
  score: number;
  outOf: number;
};
type Objective<Category extends string, State> = {
  name: Category;
  complete: boolean;
  state: State;
};
export type LogicLabSaveState = {
  problemId: string;
  timestamp: string; // ISO string
  data: {
    status: string;
    points: LabScore;
    best: LabScore;
    activityType: string;
    objectives: Objective<string, unknown>[];
  }
}

export interface Score {
  score: number;
  outOf: number;
  input: LogicLabSaveState;
  complete: boolean;
}
export interface LabMessageBase {
  attemptGuid: string; // TODO likely needed for proper message filtering
  messageType: string;
}

// Scope narrowing function.
export function isLabMessage(msg: LabMessageBase | unknown): msg is LabMessage {
  return !!msg && typeof msg == 'object' && 'messageType' in msg;
}

// For scoring attempt messages.
export interface ScoreMessage extends LabMessageBase {
  messageType: 'score';
  score: Score;
}

// For state saving messages.
export interface SaveMessage extends LabMessageBase {
  messageType: 'save';
  state: LogicLabSaveState;
}

// For state retrieving request messages.
export interface LoadMessage extends LabMessageBase {
  messageType: 'load';
}

// For logging messages.
interface LogMessage extends LabMessageBase {
  messageType: 'log';
  content: string;
}

export type LabMessage = SaveMessage | ScoreMessage | LoadMessage | LogMessage;

// Common activity specification model.
export type LabActivity = {
  id: string;
  title: string;
  version: string;
  created: string;
  modified: string;
  public: boolean;
  author?: string;
  spec: {
    type: string;
    score: string;
    preview?: string;
    // TODO objectives
    // TODO activity specific specs
  };
  comment?: string;
  keywords: string[];
};
