/*
  Models for Torus LogicLab activity data and data exchange.
*/
import { useEffect, useState } from 'react';
import { ActivityModelSchema, Feedback, Part, Transformation } from '../types';

// Typing and type checking for existence of variables in a context.
type ContextVariables = { variables: Record<string, string> };
function contextHasVariables(ctx: ContextVariables | unknown): ctx is ContextVariables {
  return !!ctx && ctx instanceof Object && 'variables' in ctx;
}
/**
 * Extract the LogicLab server URL from a context with null safety.
 * @param context deploy context or activity edit context
 * @returns the LogicLab server URL or undefined if not reachable
 */
export function useLabServer(context: ContextVariables | unknown): string | undefined {
  const [labServer, setLabServer] = useState<string | undefined>(undefined);
  useEffect(() => {
    if (contextHasVariables(context)) {
      const variables = context.variables;
      if ('ACTIVITY_LOGICLAB_URL' in variables && variables.ACTIVITY_LOGICLAB_URL) {
        setLabServer(variables.ACTIVITY_LOGICLAB_URL);
        return;
      }
    }
    console.warn('LogicLab server URL not set in context, using default.');
    // Default LogicLab server URL.
    // This default should be removed once the environment variable is consistently set in deployment environments.
    setLabServer('https://logiclab.oli.cmu.edu');
    // throw new ReferenceError('Server configuration error: LogicLab url environment variable is not set.');
  }, [context]);
  return labServer;
}

export interface LogicLabModelSchema extends ActivityModelSchema {
  activity: string | LabActivity; // Have to set at higher level as not all information in authoring.parts (eg) targets, are available in all contexts
  context?: ContextInfo;
  authoring: {
    version: 1;
    // TODO possibly extend parts to correspond to lab activity objectives?
    // However, parts is currently reserved in case an activity set type has to be implemented.
    parts: Part[]; // required in use
    transformations: Transformation[];
    previewText: string;
    source?: string; // source xml for the activity
  };
  feedback: Feedback[];
}

// info saved from Creation Context
export interface ContextInfo {
  title: string;
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
const LogiclabActivityTypes = {
  en: {
    parse_tree: 'Parse Tree',
    chase_truth: 'Chasing Truth',
    truth_table: 'Truth Table',
    truth_tree: 'Truth Tree',
    derivation: 'Derivation',
    argument_diagram: 'Argument Diagram',
  },
} as const;
export const translateActivityType = (type: string): string => {
  return (
    LogiclabActivityTypes.en[type as keyof typeof LogiclabActivityTypes.en] ??
    type ??
    'Unknown Activity Type'
  );
};
export const AllActivityTypes = Object.keys(LogiclabActivityTypes.en);

type ActivitySpecification = {
  type: keyof typeof LogiclabActivityTypes.en;
  objectives: {
    category: string;
    required: 'required' | 'optional' | 'as_required' | 'provided' | 'absent';
    mode?: 'novice' | 'expert';
  }[];
  // score: string; // Deprecated, use maximumScore instead
  maximumScore?: number;
  preview?: string | null;
  // The particulars of the various activities are not necessary here.
  // Activity specification could become important if inline editing is implemented.
  [key: string]: unknown; // Allow additional properties
};

// Common activity specification model.
export type LabActivity = {
  id: string;
  title: string;
  version: string;
  created?: string;
  modified?: string;
  public?: boolean;
  author?: string;
  spec: ActivitySpecification;
  comment?: string;
  keywords: string[];
};

/**
 * Get the maximum points for a given LabActivity.
 * This is a convenience function to extract the maximumScore from the activity specification,
 * providing a default value if it is not set to support backwards compatibility.
 * @param activity The LabActivity.
 * @returns The maximum points for the activity.
 */
export const maxPoints = (activity: LabActivity | unknown): number => {
  return isLabActivity(activity) ? activity.spec.maximumScore ?? 1 : 1;
};

/**
 * Type guard for LabActivity.
 * @param activity - The activity to check.
 * @returns True if the activity is a LabActivity, false otherwise.
 */
export function isLabActivity(activity: LabActivity | unknown): activity is LabActivity {
  return !!activity && typeof activity == 'object' && 'id' in activity && 'spec' in activity;
}
