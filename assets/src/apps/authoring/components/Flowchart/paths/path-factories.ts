import guid from '../../../../../utils/guid';
import {
  AlwaysGoToPath,
  EndOfActivityPath,
  MultipleChoiceCorrectPath,
  MultipleChoiceIncorrectPath,
  UnknownPathWithDestination,
} from './path-types';

export const createUnknownPathWithDestination = (
  destinationScreenId: number,
): UnknownPathWithDestination => ({
  type: 'unknown-reason-path',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createMultipleChoiceIncorrectPath = (
  destinationScreenId: number | null = null,
): MultipleChoiceIncorrectPath => ({
  type: 'multiple-choice-incorrect',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
  componentId: null,
  correctOption: 0,
});

export const createMultipleChoiceCorrectPath = (
  destinationScreenId: number | null = null,
): MultipleChoiceCorrectPath => ({
  type: 'multiple-choice-correct',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
  componentId: null,
  correctOption: 0,
});

export const createAlwaysGoToPath = (
  destinationScreenId: null | number = null,
): AlwaysGoToPath => ({
  type: 'always-go-to',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: !!destinationScreenId,
});

export const createEndOfActivityPath = (): EndOfActivityPath => ({
  type: 'end-of-activity',
  id: guid(),
  ruleId: null,
  completed: false,
});
