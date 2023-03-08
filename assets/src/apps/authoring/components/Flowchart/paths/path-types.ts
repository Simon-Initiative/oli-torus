export interface AuthoringFlowchartScreenData {
  paths: AllPaths[];
}

interface BasePath {
  type: RuleTypes;
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

export interface DropdownCorrectPath extends ComponentPath {
  type: 'dropdown-correct';
}

export interface DropdownIncorrectPath extends ComponentPath {
  type: 'dropdown-incorrect';
}

export interface DropdownCommonErrorPath extends ComponentPath {
  type: 'dropdown-common-error';
  selectedOption: number;
}

export interface MultipleChoiceCorrectPath extends ComponentPath {
  type: 'multiple-choice-correct';
}

export interface MultipleChoiceIncorrectPath extends ComponentPath {
  type: 'multiple-choice-incorrect';
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

export type ComponentPaths =
  | MultipleChoiceCorrectPath
  | MultipleChoiceIncorrectPath
  | MultipleChoiceCommonErrorPath
  | DropdownCorrectPath
  | DropdownIncorrectPath;

export type DestinationPaths = ComponentPaths | AlwaysGoToPath | UnknownPathWithDestination;

export type AllPaths = EndOfActivityPath | DestinationPaths;

export const ruleTypes = [
  'unknown-reason-path',
  'always-go-to',
  'multiple-choice-correct',
  'multiple-choice-incorrect',
  'multiple-choice-common-error',
  'end-of-activity',
  'dropdown-correct',
  'dropdown-incorrect',
  'dropdown-common-error',
  'unknown-reason-path',
] as const;

export const componentTypes = [
  'multiple-choice-correct',
  'multiple-choice-incorrect',
  'multiple-choice-common-error',
  'end-of-activity',
  'dropdown-correct',
  'dropdown-incorrect',
  'dropdown-common-error',
];

type RuleTuple = typeof ruleTypes;
export type RuleTypes = RuleTuple[number];
