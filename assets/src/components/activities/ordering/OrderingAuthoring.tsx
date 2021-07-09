import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { OrderingSchema } from './schema';
import * as ActivityTypes from '../types';
import { Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { Choices } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { getCorrectChoiceIds } from 'components/activities/common/responses/authoring/responseUtils';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';
import { Maybe } from 'tsmonad';
import { orderingV1toV2 } from 'components/activities/ordering/transformations/v2';
import { TargetedFeedback } from 'components/activities/ordering/sections/TargetedFeedback';

const store = configureStore();

export const Ordering: React.FC = () => {
  const { dispatch, model } = useAuthoringElementContext<OrderingSchema>();
  return (
    <TabbedNavigation.Tabs>
      <TabbedNavigation.Tab label="Question">
        <Stem />
        <Choices
          icon={(choice, index) => <span className="mr-1">{index + 1}.</span>}
          choices={model.choices}
          addOne={() => dispatch(Actions.addChoice(ActivityTypes.makeChoice('')))}
          setAll={(choices: ActivityTypes.Choice[]) =>
            dispatch(ChoiceActions.setAllChoices(choices))
          }
          onEdit={(id, content) => dispatch(ChoiceActions.editChoiceContent(id, content))}
          onRemove={(id) => dispatch(Actions.removeChoiceAndUpdateRules(id))}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Answer Key">
        <ResponseChoices
          choices={getCorrectChoiceIds(model).map((id) => getChoice(model, id))}
          setChoices={(choices) => dispatch(Actions.setCorrectChoices(choices))}
        />
        <SimpleFeedback />
        <TargetedFeedback />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Hints">
        <Hints hintsPath="$.authoring.parts[0].hints" />
      </TabbedNavigation.Tab>

      <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
    </TabbedNavigation.Tabs>
  );
};

export class OrderingAuthoring extends AuthoringElement<OrderingSchema> {
  migrateModelVersion(model: any) {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (v2) => model,
      nothing: () => orderingV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<OrderingSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Ordering />
        </AuthoringElementProvider>
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OrderingAuthoring);
