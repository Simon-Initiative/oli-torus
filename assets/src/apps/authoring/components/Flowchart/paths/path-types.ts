import { ScreenTypes } from '../screens/screen-factories';

export interface AuthoringFlowchartScreenData {
  screenType: ScreenTypes;
  paths: AllPaths[];
  templateApplied: boolean;
}

interface BasePath {
  type: RuleTypes;
  id: string;
  ruleId: string | null;
  completed: boolean;
  label: string;
  priority: number /*
  priority: Order in which the rules should be evaluated
  (lower number means higher priority)
  Guideline:   (Leaving gaps for future use)
    4 - A very specific rule, such as a specific common error
    8 - A rule that is more general, such as "any incorrect" or "correct"
    12 - The default action, such as "always go to"
    16 - End of activity
    20 - A rule that shouldn't really happen such as "never"
  */;
}
export interface DestinationPath extends BasePath {
  destinationScreenId: number | null;
}

export interface ComponentPath extends DestinationPath {
  componentId: string | null;
}

export interface CorrectPath extends ComponentPath {
  type: 'correct';
}

export interface IncorrectPath extends ComponentPath {
  type: 'incorrect';
}

export interface NumericCommonErrorPath extends ComponentPath {
  type: 'numeric-common-error';
  feedbackIndex: number;
}

export interface OptionCommonErrorPath extends ComponentPath {
  type: 'option-common-error';
  selectedOption: number;
}

export interface AlwaysGoToPath extends DestinationPath {
  type: 'always-go-to';
}

// End of activity goes to the end screen
export interface EndOfActivityPath extends BasePath {
  type: 'end-of-activity';
}

// Exit activity goes from the end screen and exits.
export interface ExitActivityPath extends BasePath {
  type: 'exit-activity';
}

// All our path types representing a "correct" answer
export const correctPathTypes = ['multiple-choice-correct'];

// Sometimes we do know where we want to go to, but we don't know why. This is a placeholder for that.
export interface UnknownPathWithDestination extends DestinationPath {
  type: 'unknown-reason-path';
}

export type ComponentPaths =
  | CorrectPath
  | IncorrectPath
  | OptionCommonErrorPath
  | NumericCommonErrorPath;

export type DestinationPaths = ComponentPaths | AlwaysGoToPath | UnknownPathWithDestination;

export type AllPaths = EndOfActivityPath | ExitActivityPath | DestinationPaths;

export const ruleTypes = [
  'unknown-reason-path',
  'always-go-to',
  'correct',
  'incorrect',
  'numeric-common-error',
  'option-common-error',
  'end-of-activity',
  'exit-activity',
  'unknown-reason-path',
] as const;

export const componentTypes = [
  'numeric-common-error',
  'option-common-error',
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
