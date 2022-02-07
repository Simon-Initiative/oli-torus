import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import { TargetedFeedback } from 'components/activities/ordering/sections/TargetedFeedback';
import { orderingV1toV2 } from 'components/activities/ordering/transformations/v2';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'data/activities/model/choices';
import { getCorrectChoiceIds } from 'data/activities/model/responses';
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
import * as ActivityTypes from '../types';
import { Actions } from './actions';
import { OrderingSchema } from './schema';

const store = configureStore();

export const Ordering: React.FC = () => {
  const { dispatch, model } = useAuthoringElementContext<OrderingSchema>();

  const choices = model.choices.reduce((m: any, c) => {
    m[c.id] = c;
    return m;
  }, {});

  return (
    <TabbedNavigation.Tabs>
      <TabbedNavigation.Tab label="Question">
        <Stem />
        <ChoicesAuthoring
          icon={(choice, index) => <span className="mr-1">{index + 1}.</span>}
          choices={model.choices}
          addOne={() => dispatch(Actions.addChoice(ActivityTypes.makeChoice('')))}
          setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
          onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
          onRemove={(id) => dispatch(Actions.removeChoiceAndUpdateRules(id))}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Answer Key">
        <ResponseChoices
          choices={getCorrectChoiceIds(model).map((id) => choices[id])}
          setChoices={(choices) => dispatch(Actions.setCorrectChoices(choices))}
        />
        <SimpleFeedback partId={DEFAULT_PART_ID} />
        <TargetedFeedback />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Hints">
        <Hints partId={DEFAULT_PART_ID} />
      </TabbedNavigation.Tab>

      <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
    </TabbedNavigation.Tabs>
  );
};

export class OrderingAuthoring extends AuthoringElement<OrderingSchema> {
  migrateModelVersion(model: any) {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (_v2) => model,
      nothing: () => orderingV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<OrderingSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Ordering />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OrderingAuthoring);
