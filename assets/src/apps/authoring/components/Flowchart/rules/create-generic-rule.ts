import guid from '../../../../../utils/guid';
import {
  IAction,
  IAdaptiveRule,
  ICondition,
} from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { AlwaysGoToPath, DestinationPath } from '../paths/path-types';
import { createFeedbackAction } from './create-feedback-action';
import { createNavigationAction } from './create-navigation-action';

// export const generateOptionCommonError = (
//   path: OptionCommonErrorPath,
//   sequence: SequenceEntry<SequenceEntryChild>[],
//   screen: IActivity,
// ): IAdaptiveRule[] => {
//   const rule = createRuleTemplate('option-common-error');
//   rule.correct = false;
//   const sequenceEntry = sequence.find((s) => s.resourceId === path.destinationScreenId);
//   const question = getScreenPrimaryQuestion(screen);
//   const questionType = getScreenQuestionType(screen);
//   if (!sequenceEntry) {
//     console.warn("Couldn't find sequence entry for path", path);
//     return [];
//   }

//   // TODO - add feedback option
//   rule.event.params.actions = [createNavigationAction(sequenceEntry.custom.sequenceId)];

//   switch (questionType) {
//     case 'dropdown':
//       rule.conditions = {
//         all: createDropdownCommonErrorCondition(path, question as IDropdownPartLayout),
//       };
//       break;
//     default:
//       console.warn('Unknown question type while generating rules', questionType);
//   }

//   return [rule];
// };

export const generateDestinationRule = (
  label: string,
  conditions: ICondition[],
  destinationId: string | null,
  correct: boolean,
  feedback: string | null = null,
  additionalActions: IAction[] = [],
): IAdaptiveRule => {
  const rule = createRuleTemplate(label);
  rule.correct = correct;

  rule.event.params.actions = [];
  if (destinationId) {
    rule.event.params.actions.push(createNavigationAction(destinationId));
  }

  if (feedback) {
    rule.event.params.actions.push(createFeedbackAction(feedback));
  }

  if (additionalActions) {
    rule.event.params.actions.push(...additionalActions);
  }

  rule.conditions = {
    all: conditions,
  };

  return rule;
};

export const createRuleTemplate = (label: string): IAdaptiveRule => {
  return {
    id: `r:${guid()}.${label}`,
    name: label,
    priority: 1,
    event: {
      type: `r:${guid()}.${label}`,
      params: {
        actions: [],
      },
    },
    correct: true,
    default: false,
    disabled: false,
    conditions: {
      id: `b:${guid()}`,
      all: [],
    },
    forceProgress: false,
    additionalScore: 0,
  };
};

export const generateAlwaysGoTo = (
  path: AlwaysGoToPath,
  sequence: SequenceEntry<SequenceEntryChild>[],
): IAdaptiveRule[] => {
  const rule = createRuleTemplate('always');
  const sequenceEntry = sequence.find((s) => s.resourceId === path.destinationScreenId);
  if (!sequenceEntry) {
    console.warn("Couldn't find sequence entry for path", path);
    return [];
  }
  rule.event.params.actions = [createNavigationAction(sequenceEntry.custom.sequenceId)];

  return [rule];
};

export interface IConditionWithFeedback {
  conditions: ICondition[];
  destinationId?: string;
  feedback?: string;
}

export const newId = (condition: ICondition): ICondition => ({
  ...condition,
  id: guid(),
});

export const getSequenceIdFromDestinationPath = (
  path: DestinationPath,
  sequence: SequenceEntry<SequenceEntryChild>[],
) => {
  const sequenceEntry = sequence.find((s) => s.resourceId === path.destinationScreenId);
  return sequenceEntry?.custom.sequenceId;
};

export const getSequenceIdFromScreenResourceId = (
  id: number | undefined,
  sequence: SequenceEntry<SequenceEntryChild>[],
) => {
  if (!id) return undefined;
  const sequenceEntry = sequence.find((s) => s.resourceId === id);
  return sequenceEntry?.custom.sequenceId;
};

export const createNeverCondition = (): ICondition => ({
  fact: '0',
  operator: 'equal',
  value: '1',
  type: 1,
  id: guid(),
});

export const DEFAULT_CORRECT_FEEDBACK = "That's correct!";
export const DEFAULT_INCORRECT_FEEDBACK = "That's incorrect. Please try again.";
export const DEFAULT_BLANK_FEEDBACK = 'Please choose an answer.';
export const DEFAULT_FILLED_IN_FEEDBACK =
  'You seem to be having trouble. We have filled in the correct answer for you. Click next to continue.';
