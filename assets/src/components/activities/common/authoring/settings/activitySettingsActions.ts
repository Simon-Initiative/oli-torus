import {
  isShuffled,
  toggleAnswerChoiceShuffling,
  togglePerPartSubmissionOption,
} from 'components/activities/common/utils';
import { HasTransformations, HasPerPartSubmissionOption } from 'components/activities/types';

export const shuffleAnswerChoiceSetting = (
  model: HasTransformations,
  dispatch: (action: any) => void,
) => ({
  isEnabled: isShuffled(model.authoring.transformations),
  label: 'Shuffle answer choices',
  onToggle: () => dispatch(toggleAnswerChoiceShuffling()),
});

export const changePerPartSubmission = (
  model: HasPerPartSubmissionOption,
  dispatch: (action: any) => void,
) => ({
  isEnabled: model.submitPerPart === true,
  label: 'Submit answers per input',
  onToggle: () => dispatch(togglePerPartSubmissionOption()),
});
