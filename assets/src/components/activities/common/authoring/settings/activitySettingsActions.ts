import { isShuffled, toggleAnswerChoiceShuffling } from 'components/activities/common/utils';
import { HasTransformations } from 'components/activities/types';

export const shuffleAnswerChoiceSetting = (
  model: HasTransformations,
  dispatch: (action: any) => void,
) => ({
  isEnabled: isShuffled(model.authoring.transformations),
  label: 'Shuffle answer choice order',
  onToggle: () => dispatch(toggleAnswerChoiceShuffling()),
});
