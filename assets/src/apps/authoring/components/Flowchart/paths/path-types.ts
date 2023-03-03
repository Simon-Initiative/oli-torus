export interface AuthoringFlowchartScreenData {
  paths: AllPaths[];
}

interface BasePath {
  type: string;
  id: string;
  ruleId: string | null;
  completed: boolean;
}
export interface DestinationPath extends BasePath {
  destinationScreenId: number | null;
}

export interface ComponentPath extends DestinationPath {
  componentId: string | null;
}

export interface MultipleChoiceCorrectPath extends ComponentPath {
  type: 'multiple-choice-correct';
  correctOption: number;
}

export interface MultipleChoiceIncorrectPath extends ComponentPath {
  type: 'multiple-choice-incorrect';
  correctOption: number;
}

export interface MultipleChoiceCommonErrorPath extends ComponentPath {
  type: 'multiple-choice-common-error';
  selectedOption: number;
}

export interface AlwaysGoToPath extends DestinationPath {
  type: 'always-go-to';
}

export interface EndOfActivityPath extends BasePath {
  type: 'end-of-activity';
}

// All our path types representing a "correct" answer
export const correctPathTypes = ['multiple-choice-correct'];

// Sometimes we do know where we want to go to, but we don't know why. This is a placeholder for that.
export interface UnknownPathWithDestination extends DestinationPath {
  type: 'unknown-reason-path';
}

export type DestinationPaths =
  | MultipleChoiceCorrectPath
  | MultipleChoiceIncorrectPath
  | MultipleChoiceCommonErrorPath
  | AlwaysGoToPath
  | UnknownPathWithDestination;

export type AllPaths = EndOfActivityPath | DestinationPaths;

export type RuleTypes = AllPaths['type'];
