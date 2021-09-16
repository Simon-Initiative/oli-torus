import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { mcV1toV2 } from 'components/activities/multiple_choice/transformations/v2';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { Radio } from 'components/misc/icons/radio/Radio';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'data/activities/model/choices';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { Maybe } from 'tsmonad';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { MCActions as Actions } from '../common/authoring/actions/multipleChoiceActions';
import * as ActivityTypes from '../types';
import { MCSchema } from './schema';

const store = configureStore();

const MultipleChoice: React.FC = () => {
  const { dispatch, model } = useAuthoringElementContext<MCSchema>();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Stem />

          <ChoicesAuthoring
            icon={<Radio.Unchecked />}
            choices={model.choices}
            addOne={() => dispatch(Choices.addOne(ActivityTypes.makeChoice('')))}
            setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
            onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
            onRemove={(id) => dispatch(Actions.removeChoice(id))}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <StemDelivery stem={model.stem} context={defaultWriterContext()} />

          <ChoicesDelivery
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
            choices={model.choices}
            selected={[getCorrectChoice(model).id]}
            onSelect={(id) => dispatch(Actions.toggleChoiceCorrectness(id))}
            isEvaluated={false}
            context={defaultWriterContext()}
          />
          <SimpleFeedback partId={DEFAULT_PART_ID} />
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
          <Hints partId={DEFAULT_PART_ID} />
        </TabbedNavigation.Tab>
        <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
      </TabbedNavigation.Tabs>
    </>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MCSchema> {
  migrateModelVersion(model: any): MCSchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (_v2) => model,
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
