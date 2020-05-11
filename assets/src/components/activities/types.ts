import { ResourceContext } from 'data/content/resource';
import { Identifiable, ModelElement } from 'data/content/model';

export type RichText = ModelElement[];

export interface Success {
  type: 'success';
}

export interface HasContent {
  content: RichText;
}

export interface StudentResponse {
  input: any;
}

export type ModeSpecification = {
  element: string,
  entry: string,
};

export type Manifest = {
  id: string,
  friendlyName: string,
  description: string,
  delivery: ModeSpecification,
  authoring: ModeSpecification,
};

export interface ActivityModelSchema {
  authoring?: any;
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
  partId: number;
  hasMoreAttempts: boolean;
  hasMoreHints: boolean;
}

export interface ActivityState {
  attemptGuid: string;
  attemptNumber: number;
  dateEvaluated: Date | null;
  score: number | null;
  outOf: number | null;
  parts: PartState[];
  hasMoreAttempts: boolean;
  hasMoreHints: boolean;
}

export interface Hint extends Identifiable, HasContent {}
export interface Feedback extends Identifiable, HasContent {}
export interface Transformation extends Identifiable {
  path: string;
  operation: Operation;
}

export interface Response extends Identifiable {
  // `match` corresponds to Choice::id. Later, it can be used
  // for a catch-all and non 1:1 choice:feedback mappings
  match: string | number;
  // `score == 1` indicates the feedback corresponds to a matching choice
  score: number;

  feedback: Feedback;
}

export interface Part extends Identifiable {
  responses: Response[];
  hints: Hint[];
  scoringStrategy: ScoringStrategy;
  evaluationStrategy: EvaluationStrategy;
}

export enum ScoringStrategy {
  'average' = 'average',
  'best' = 'best',
  'most_recent' = 'most_recent',
}

export enum EvaluationStrategy {
  'regex' = 'regex',
  'numeric' = 'numeric',
}

export enum Operation {
  'shuffle' = 'shuffle',
}

export interface CreationContext extends ResourceContext {

}
