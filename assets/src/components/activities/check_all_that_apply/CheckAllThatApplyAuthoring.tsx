import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
} from '../AuthoringElement';
import { CheckAllThatApplyModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import produce from 'immer';
import {
  getBottomOutHint,
  getCognitiveHints,
  getCorrectChoiceIds,
  getCorrectResponse,
  getDeerInHeadlightsHint,
  getIncorrectResponse,
  getTargetedResponseMappings,
  isTargetedCATA,
} from 'components/activities/check_all_that_apply/utils';
import { StemAuthoring } from 'components/activities/common/stem/StemAuthoring';
import { ChoicesAuthoringConnected } from 'components/activities/common/choices/ChoicesAuthoring';
import { Checkbox } from 'components/activities/common/icons/Checkbox';
import { HintsAuthoring } from 'components/activities/common/hints/HintsAuthoring';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { AnswerKeyAuthoring } from 'components/activities/common/authoring/answerKey/AnswerKeyAuthoring';
import { CheckAllThatApplySettings } from 'components/activities/check_all_that_apply/Settings';
import { SimpleFeedback } from 'components/activities/common/feedback/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/feedback/TargetedFeedback';

const store = configureStore();

const CheckAllThatApply = (props: AuthoringElementProps<CheckAllThatApplyModelSchema>) => {
  const dispatch = (action: any) => props.onEdit(produce(props.model, action));

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
    projectSlug: props.projectSlug,
  };

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <StemAuthoring
            {...sharedProps}
            stem={props.model.stem}
            onEdit={(content) => dispatch(Actions.editStem(content))}
          />

          <ChoicesAuthoringConnected
            icon={<Checkbox.Unchecked />}
            choices={props.model.choices}
            addOne={() => dispatch(Actions.addChoice())}
            setAll={(choices: ActivityTypes.Choice[]) => dispatch(Actions.setAllChoices(choices))}
            onEdit={(id, content) => dispatch(Actions.editChoiceContent(id, content))}
            onRemove={(id) => dispatch(Actions.removeChoice(id))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <AnswerKeyAuthoring
            stem={props.model.stem}
            choices={props.model.choices}
            selectedChoiceIds={getCorrectChoiceIds(props.model)}
            selectedIcon={<Checkbox.Correct />}
            unselectedIcon={<Checkbox.Unchecked />}
            onSelectChoiceId={(id) => dispatch(Actions.toggleChoiceCorrectness(id))}
          />
          <SimpleFeedback
            correctResponse={getCorrectResponse(props.model)}
            incorrectResponse={getIncorrectResponse(props.model)}
            update={(id, content) => dispatch(Actions.editResponseFeedback(id, content))}
          />

          {/*
Fix CATA UI tests
*/}

          {isTargetedCATA(props.model) && (
            <TargetedFeedback
              choices={props.model.choices}
              targetedMappings={getTargetedResponseMappings(props.model)}
              toggleChoice={(choiceId, mapping) => {
                dispatch(
                  Actions.editTargetedFeedbackChoices(
                    mapping.response.id,
                    mapping.choiceIds.includes(choiceId)
                      ? mapping.choiceIds.filter((id) => id !== choiceId)
                      : mapping.choiceIds.concat(choiceId),
                  ),
                );
              }}
              updateResponse={(id, content) => dispatch(Actions.editResponseFeedback(id, content))}
              addTargetedResponse={() => dispatch(Actions.addTargetedFeedback())}
              unselectedIcon={<Checkbox.Unchecked />}
              selectedIcon={<Checkbox.Checked />}
              onRemove={(id) => dispatch(Actions.removeTargetedFeedback(id))}
            />
          )}
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <HintsAuthoring
            addOne={() => dispatch(Actions.addHint())}
            updateOne={(id, content) => dispatch(Actions.editHint(id, content))}
            removeOne={(id) => dispatch(Actions.removeHint(id))}
            deerInHeadlightsHint={getDeerInHeadlightsHint(props.model)}
            cognitiveHints={getCognitiveHints(props.model)}
            bottomOutHint={getBottomOutHint(props.model)}
          />
        </TabbedNavigation.Tab>
        <CheckAllThatApplySettings dispatch={dispatch} model={props.model} />
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
