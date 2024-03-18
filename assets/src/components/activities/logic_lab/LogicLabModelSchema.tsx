/*
  Models for Torus LogicLab activity data and data exchange.
*/
import { ActivityModelSchema, CreationContext, Feedback, Part, Transformation } from '../types';

export interface LogicLabModelSchema extends ActivityModelSchema {
  src: string; // URL of servlet
  activity: string; // Have to set at higher level as not all information in authoring.parts (eg) targets, are available in all contexts
  context?: CreationContext;
  authoring: {
    version: 1;
    parts: Part[]; // required in use
    transformations: Transformation[];
    previewText: string;
  };
  feedback: Feedback[];
}

export interface Score {
  score: number;
  outOf: number;
  input: unknown;
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
  state: unknown;
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
