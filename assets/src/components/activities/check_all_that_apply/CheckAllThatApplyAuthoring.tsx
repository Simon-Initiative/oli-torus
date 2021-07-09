import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import * as ActivityTypes from '../types';
import { CATAActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { AnswerKey } from 'components/activities/common/authoring/answerKey/AnswerKey';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { getCorrectChoiceIds } from 'components/activities/common/responses/authoring/responseUtils';
import { Maybe } from 'tsmonad';
import { cataV1toV2 } from 'components/activities/check_all_that_apply/transformations/v2';
import { CATASchema } from 'components/activities/check_all_that_apply/schema';

const store = configureStore();

const CheckAllThatApply = () => {
  const { dispatch, model } = useAuthoringElementContext<CATASchema>();
  return (
    <TabbedNavigation.Tabs>
      <TabbedNavigation.Tab label="Question">
        <Stem />
        <Choices
          icon={<Checkbox.Unchecked />}
          choices={model.choices}
          addOne={() => dispatch(CATAActions.addChoice(ActivityTypes.makeChoice('')))}
          setAll={(choices: ActivityTypes.Choice[]) =>
            dispatch(ChoiceActions.setAllChoices(choices))
          }
          onEdit={(id, content) => dispatch(ChoiceActions.editChoiceContent(id, content))}
          onRemove={(id) => dispatch(CATAActions.removeChoiceAndUpdateRules(id))}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Answer Key">
        <AnswerKey
          selectedChoiceIds={getCorrectChoiceIds(model)}
          selectedIcon={<Checkbox.Correct />}
          unselectedIcon={<Checkbox.Unchecked />}
          onSelectChoiceId={(id) => dispatch(CATAActions.toggleChoiceCorrectness(id))}
        />
        <SimpleFeedback />
        <TargetedFeedback
          toggleChoice={(choiceId, mapping) => {
            dispatch(
              CATAActions.editTargetedFeedbackChoices(
                mapping.response.id,
                mapping.choiceIds.includes(choiceId)
                  ? mapping.choiceIds.filter((id) => id !== choiceId)
                  : mapping.choiceIds.concat(choiceId),
              ),
            );
          }}
          addTargetedResponse={() => dispatch(CATAActions.addTargetedFeedback())}
          unselectedIcon={<Checkbox.Unchecked />}
          selectedIcon={<Checkbox.Checked />}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Hints">
        <Hints hintsPath="$.authoring.parts[0].hints" />
      </TabbedNavigation.Tab>

      <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
    </TabbedNavigation.Tabs>
  );
};

export class CheckAllThatApplyAuthoring extends AuthoringElement<CATASchema> {
  migrateModelVersion(model: any): CATASchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (v2) => model,
      nothing: () => cataV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<CATASchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <CheckAllThatApply />
        </AuthoringElementProvider>
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, CheckAllThatApplyAuthoring);
