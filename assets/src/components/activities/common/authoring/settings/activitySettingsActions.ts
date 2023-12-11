import {
  isShuffled,
  toggleAnswerChoiceShuffling,
  togglePerPartSubmissionOption,
} from 'components/activities/common/utils';
import { MultiInput } from 'components/activities/multi_input/schema';
import { HasPerPartSubmissionOption, HasTransformations } from 'components/activities/types';

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
