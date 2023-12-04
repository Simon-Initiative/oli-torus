import {
  isShuffled,
  toggleAnswerChoiceShuffling,
  toggleMultInputsPerPartOption,
  togglePerPartSubmissionOption,
} from 'components/activities/common/utils';
import { MultiInput } from 'components/activities/multi_input/schema';
import {
  HasMultInputsPerPartOption,
  HasPerPartSubmissionOption,
  HasTransformations,
} from 'components/activities/types';

export const shuffleAnswerChoiceSetting = (
  model: HasTransformations,
  dispatch: (action: any) => void,
  input?: MultiInput,
) =>
  input
    ? input?.inputType === 'dropdown' && {
        isEnabled: isShuffled(model.authoring.transformations, input.partId),
        label: `Shuffle dropdown choices`,
        onToggle: () => dispatch(toggleAnswerChoiceShuffling(input.partId)),
      }
    : {
        isEnabled: isShuffled(model.authoring.transformations),
        label: 'Shuffle answer choices',
        onToggle: () => dispatch(toggleAnswerChoiceShuffling()),
      };

export const changePerPartSubmission = (
  model: HasPerPartSubmissionOption,
  dispatch: (action: any) => void,
) => ({
  isEnabled: model.submitPerPart === true,
  label: 'Submit answers per input',
  onToggle: () => dispatch(togglePerPartSubmissionOption()),
});

export const changeMultInputPerPartSubmission = (
  model: HasMultInputsPerPartOption,
  dispatch: (action: any) => void,
) => ({
  isEnabled: model.multInputsPerPart === true,
  label: 'Author response multi',
  onToggle: () => dispatch(toggleMultInputsPerPartOption()),
});
