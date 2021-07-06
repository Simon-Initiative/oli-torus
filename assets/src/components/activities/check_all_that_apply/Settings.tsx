import React from 'react';
import { CheckAllThatApplyModelSchema } from 'components/activities/check_all_that_apply/schema';
import { CATAActions } from 'components/activities/check_all_that_apply/actions';
import { isTargetedCATA } from 'components/activities/check_all_that_apply/utils';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { useAuthoringElementContext } from 'components/activities/AuthoringElement';

export const CATASettingsConnected: React.FC = () => {
  const { dispatch, model } = useAuthoringElementContext<CheckAllThatApplyModelSchema>();
  return (
    <ActivitySettings
      settings={[
        shuffleAnswerChoiceSetting(model, dispatch),
        {
          isEnabled: isTargetedCATA(model),
          label: 'Targeted feedback',
          onToggle: () => dispatch(CATAActions.toggleType()),
        },
      ]}
    />
  );
};
