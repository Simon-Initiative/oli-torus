import {
  IAction,
  IActivity,
  IAdaptiveRule,
  ICondition,
  IInputTextPartLayout,
  IMultiLineTextPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenPrimaryQuestion } from '../paths/path-options';
import { isAlwaysPath, isDestinationPath } from '../paths/path-utils';
import { createCondition } from './create-condition';
import {
  DEFAULT_CORRECT_FEEDBACK,
  generateRule,
  getSequenceIdFromScreenResourceId,
} from './create-generic-rule';
import { RulesAndVariables } from './rule-compilation';

// This one doesn't follow the 3-tries model, it's just a straight up "did you type enough characters" check

export const generateMultilineTextInputRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const question = getScreenPrimaryQuestion(screen) as IMultiLineTextPartLayout;
  const alwaysPath = (screen.authoring?.flowchart?.paths || []).find(isAlwaysPath);
  const destinationPath = (screen.authoring?.flowchart?.paths || []).find(isDestinationPath); // Fallback to any other destination we can find
  const rules: IAdaptiveRule[] = [];

  const longEnough: ICondition = createCondition(
    `stage.${question.id}.textLength`,
    String(question.custom?.minimumLength || 0),
    'greaterThanInclusive',
  );

  const tooShort: ICondition = createCondition(
    `stage.${question.id}.textLength`,
    String(question.custom?.minimumLength || 0),
    'lessThan',
  );

  const destination: string =
    getSequenceIdFromScreenResourceId(
      alwaysPath?.destinationScreenId || destinationPath?.destinationScreenId || defaultDestination,
      sequence,
    ) || sequence[0].custom.sequenceId;

  const disableAction: IAction = {
    // Disables the dropdown so the correct answer can be unselected
    type: 'mutateState',
    params: {
      value: 'false',
      target: `stage.${question.id}.enabled`,
      operator: '=',
      targetType: 4,
    },
  };

  rules.push(
    generateRule(
      'too-short',
      [tooShort],
      null,
      false,
      50,
      question.custom?.incorrectFeedback || 'Please type more to finish your answer',
    ),
  );

  rules.push(
    generateRule(
      'correct',
      [longEnough],
      destination,
      true,
      50,
      question.custom?.correctFeedback || DEFAULT_CORRECT_FEEDBACK,
      [disableAction],
      { default: true },
    ),
  );

  return {
    rules,
    variables: [`stage.${question.id}.textLength`],
  };
};
