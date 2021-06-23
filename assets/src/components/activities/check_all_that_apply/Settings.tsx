import { isShuffled, toggleAnswerChoiceShuffling } from 'components/activities/common/utils';
import { SettingsComponent } from 'components/activities/common/authoring/settings/main';
import React from 'react';
import { CheckAllThatApplyModelSchema } from 'components/activities/check_all_that_apply/schema';
import { Actions } from 'components/activities/check_all_that_apply/actions';
import { isTargetedCATA } from 'components/activities/check_all_that_apply/utils';

interface Props {
  dispatch: (action: any) => void;
  model: CheckAllThatApplyModelSchema;
}
export const CheckAllThatApplySettings: React.FC<Props> = ({ dispatch, model }) => {
  return (
    <SettingsComponent
      settings={[
        {
          isEnabled: isShuffled(model.authoring.transformations),
          label: 'Shuffle answer choice order',
          onToggle: () => dispatch(toggleAnswerChoiceShuffling()),
        },
        {
          isEnabled: isTargetedCATA(model),
          label: 'Targeted feedback',
          onToggle: () => dispatch(Actions.toggleType()),
        },
      ]}
    />
  );
};
