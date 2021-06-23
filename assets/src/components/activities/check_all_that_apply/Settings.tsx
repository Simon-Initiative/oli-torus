import { connect } from 'react-redux';
import { createAction } from '@reduxjs/toolkit';
import { HasTransformations } from 'components/activities/types';
import { isShuffled } from 'components/activities/common/utils';
import { Setting } from 'components/activities/common/authoring/settings/main';

const toggleAnswerChoiceShuffling = createAction<void>('settings/toggleAnswerChoiceShuffling');
const toggleTargetedFeedback = createAction<void>('settings/toggleTargetedFeedback');
export const CheckAllThatApplySettings = connect(
  (state: HasTransformations & HasResponseMappings) => ({
    settingsState: [
      {
        isEnabled: isShuffled(selectAllTransformations(state)),
        label: 'Shuffle answer choice order',
      },
      {
        // isEnabled: isTargetedFeedbackEnabled(state),
        isEnabled: true,
        label: 'Targeted feedback',
      },
      {
        isEnabled: true,
        label: 'Partial credit',
      },
    ],
  }),
  (dispatch) => ({
    settingsDispatch: [
      { onToggle: () => dispatch(toggleAnswerChoiceShuffling()) },
      { onToggle: () => dispatch(toggleTargetedFeedback()) },
      { onToggle: () => undefined },
    ],
  }),
  (stateProps, dispatchProps) => ({
    // zip both lists together into a single list of Setting objects
    settings: stateProps.settingsState.reduce(
      (acc, settingsState, i) =>
        acc.concat({ ...settingsState, ...dispatchProps.settingsDispatch[i] }),
      [] as Setting[],
    ),
  }),
)(CheckAllThatApplySettingsComponent);
