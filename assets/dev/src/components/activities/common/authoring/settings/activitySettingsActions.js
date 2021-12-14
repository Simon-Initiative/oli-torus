import { isShuffled, toggleAnswerChoiceShuffling } from 'components/activities/common/utils';
export const shuffleAnswerChoiceSetting = (model, dispatch) => ({
    isEnabled: isShuffled(model.authoring.transformations),
    label: 'Shuffle answer choice order',
    onToggle: () => dispatch(toggleAnswerChoiceShuffling()),
});
//# sourceMappingURL=activitySettingsActions.js.map