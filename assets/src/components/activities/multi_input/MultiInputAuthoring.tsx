import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { MultiInputSchema } from './schema';
import * as ActivityTypes from '../types';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { MCActions as Actions } from '../common/authoring/actions/multipleChoiceActions';
import { Radio } from 'components/misc/icons/radio/Radio';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { defaultWriterContext } from 'data/content/writers/context';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { toSimpleText } from 'data/content/text';

const store = configureStore();

const MultiInput = () => {
  const { dispatch, model } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Stem />

          <Choices
            icon={(_c, i) => <span>{i + 1}.</span>}
            choices={model.choices}
            addOne={() => dispatch(ChoiceActions.addChoice(ActivityTypes.makeChoice('')))}
            setAll={(choices: ActivityTypes.Choice[]) =>
              dispatch(ChoiceActions.setAllChoices(choices))
            }
            onEdit={(id, content) => dispatch(ChoiceActions.editChoiceContent(id, content))}
            onRemove={(id) => dispatch(Actions.removeChoice(id))}
            simpleText
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <StemDelivery stem={model.stem} context={defaultWriterContext()} />
          <select
            onChange={(e) => dispatch(Actions.toggleChoiceCorrectness(e.target.value))}
            className="custom-select mb-3"
          >
            {model.choices.map((c) => (
              <option selected={getCorrectChoice(model).id === c.id} key={c.id} value={c.id}>
                {toSimpleText({ children: c.content.model })}
              </option>
            ))}
          </select>
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

export class MultiInputAuthoring extends AuthoringElement<MultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultiInputSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInput />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultiInputAuthoring);
