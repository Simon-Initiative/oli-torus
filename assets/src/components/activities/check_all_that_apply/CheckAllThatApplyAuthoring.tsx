import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { CheckAllThatApplyModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { CATAActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import {
  getCorrectChoiceIds,
  getCorrectResponse,
  getIncorrectResponse,
  getTargetedResponseMappings,
  isTargetedCATA,
} from 'components/activities/check_all_that_apply/utils';
import { StemAuthoring } from 'components/activities/common/stem/StemAuthoring';
import { ChoicesAuthoringConnected } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Checkbox } from 'components/activities/common/icons/Checkbox';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { AnswerKeyAuthoring } from 'components/activities/common/authoring/answerKey/AnswerKeyAuthoring';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HintsAuthoringConnected } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { CATASettingsConnected } from 'components/activities/check_all_that_apply/Settings';

const store = configureStore();

const CheckAllThatApply = (props: AuthoringElementProps<CheckAllThatApplyModelSchema>) => {
  const { dispatch } = useAuthoringElementContext();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <StemAuthoring
            stem={props.model.stem}
            onEdit={(content) => dispatch(StemActions.editStemAndPreviewText(content))}
          />

          <ChoicesAuthoringConnected
            icon={<Checkbox.Unchecked />}
            choices={props.model.choices}
            addOne={() => dispatch(CATAActions.addChoice(ActivityTypes.makeChoice('')))}
            setAll={(choices: ActivityTypes.Choice[]) =>
              dispatch(ChoiceActions.setAllChoices(choices))
            }
            onEdit={(id, content) => dispatch(ChoiceActions.editChoiceContent(id, content))}
            onRemove={(id) => dispatch(CATAActions.removeChoice(id))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <AnswerKeyAuthoring
            stem={props.model.stem}
            choices={props.model.choices}
            selectedChoiceIds={getCorrectChoiceIds(props.model)}
            selectedIcon={<Checkbox.Correct />}
            unselectedIcon={<Checkbox.Unchecked />}
            onSelectChoiceId={(id) => dispatch(CATAActions.toggleChoiceCorrectness(id))}
          />
          <SimpleFeedback
            correctResponse={getCorrectResponse(props.model)}
            incorrectResponse={getIncorrectResponse(props.model)}
            update={(id, content) => dispatch(ResponseActions.editResponseFeedback(id, content))}
          />

          {isTargetedCATA(props.model) && (
            <TargetedFeedback
              choices={props.model.choices}
              targetedMappings={getTargetedResponseMappings(props.model)}
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
              updateResponse={(id, content) =>
                dispatch(ResponseActions.editResponseFeedback(id, content))
              }
              addTargetedResponse={() => dispatch(CATAActions.addTargetedFeedback())}
              unselectedIcon={<Checkbox.Unchecked />}
              selectedIcon={<Checkbox.Checked />}
              onRemove={(id) => dispatch(CATAActions.removeTargetedFeedback(id))}
            />
          )}
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <HintsAuthoringConnected />
        </TabbedNavigation.Tab>
        <CATASettingsConnected />
      </TabbedNavigation.Tabs>
    </>
  );
};

export class CheckAllThatApplyAuthoring extends AuthoringElement<CheckAllThatApplyModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<CheckAllThatApplyModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <CheckAllThatApply {...props} />
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
