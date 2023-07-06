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

export const generateRule = (
  label: string,
  conditions: ICondition[],
  destinationId: string | null,
  correct: boolean,
  priority: number,
  feedback: string | null = null,
  additionalActions: IAction[] = [],
  extra: Partial<IAdaptiveRule> = {},
): IAdaptiveRule => {
  const rule = createRuleTemplate(label);
  rule.correct = correct;
  rule.priority = priority;

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

  return {
    ...rule,
    ...extra,
  };
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

export const defaultNextScreenRule = (): IAdaptiveRule => ({
  id: `r:${guid()}.default`,
  name: 'default',
  priority: 1,
  event: {
    type: `r:${guid()}.default`,
    params: {
      actions: [
        {
          type: 'navigation',
          params: {
            target: 'next',
          },
        },
      ],
    },
  },
  correct: true,
  default: true,
  disabled: false,
  conditions: {
    id: `b:${guid()}`,
    all: [],
  },
  forceProgress: false,
  additionalScore: 0,
});

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

export const getActivitySlugFromScreenResourceId = (
  id: number | undefined,
  sequence: SequenceEntry<SequenceEntryChild>[],
) => {
  if (!id) return undefined;
  const sequenceEntry = sequence.find((s) => s.resourceId === id);
  return sequenceEntry?.activitySlug;
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
export const DEFAULT_BLANK_FEEDBACK = 'Please answer the question.';
export const DEFAULT_FILLED_IN_FEEDBACK =
  'You seem to be having trouble. We have filled in the correct answer for you. Click next to continue.';
