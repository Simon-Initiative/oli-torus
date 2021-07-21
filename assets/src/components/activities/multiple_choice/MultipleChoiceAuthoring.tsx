import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { MCSchema } from './schema';
import * as ActivityTypes from '../types';
import { MCActions as Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Radio } from 'components/misc/icons/radio/Radio';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { AnswerKey } from 'components/activities/common/authoring/answerKey/AnswerKey';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { Maybe } from 'tsmonad';
import { mcV1toV2 } from 'components/activities/multiple_choice/transformations/v2';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';

const store = configureStore();

const MultipleChoice: React.FC = () => {
  const { dispatch, model } = useAuthoringElementContext<MCSchema>();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Stem />

          <Choices
            icon={<Radio.Unchecked />}
            choices={model.choices}
            addOne={() => dispatch(ChoiceActions.addChoice(ActivityTypes.makeChoice('')))}
            setAll={(choices: ActivityTypes.Choice[]) =>
              dispatch(ChoiceActions.setAllChoices(choices))
            }
            onEdit={(id, content) => dispatch(ChoiceActions.editChoiceContent(id, content))}
            onRemove={(id) => dispatch(Actions.removeChoice(id))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <AnswerKey
            selectedChoiceIds={[getCorrectChoice(model).id]}
            selectedIcon={<Radio.Correct />}
            unselectedIcon={<Radio.Unchecked />}
            onSelectChoiceId={(id) => dispatch(Actions.toggleChoiceCorrectness(id))}
          />
          <SimpleFeedback />
          <TargetedFeedback
            toggleChoice={(choiceId, mapping) => {
              dispatch(Actions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
            }}
            addTargetedResponse={() => dispatch(Actions.addTargetedFeedback())}
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints hintsPath="$.authoring.parts[0].hints" />
        </TabbedNavigation.Tab>
        <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
      </TabbedNavigation.Tabs>
    </>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MCSchema> {
  migrateModelVersion(model: any): MCSchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (v2) => model,
      nothing: () => mcV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MCSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultipleChoice />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
