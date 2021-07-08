import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { OrderingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { StemAuthoringConnected } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { ChoicesAuthoringConnected } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { HintsAuthoringConnected } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { OrderingChoices } from 'components/activities/ordering/sections/OrderingChoices';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { isTargetedOrdering } from 'components/activities/ordering/utils';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import {
  getCorrectResponse,
  getIncorrectResponse,
} from 'components/activities/common/responses/authoring/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { getTargetedResponseMappings } from 'components/activities/check_all_that_apply/utils';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';

const store = configureStore();

export const Ordering: React.FC = () => {
  const { dispatch, model } = useAuthoringElementContext<OrderingModelSchema>();
  return (
    <TabbedNavigation.Tabs>
      <TabbedNavigation.Tab label="Question">
        <StemAuthoringConnected />
        <ChoicesAuthoringConnected
          icon={(choice, index) => <span className="mr-1">{index + 1}.</span>}
          choices={model.choices}
          addOne={() => dispatch(Actions.addChoice(ActivityTypes.makeChoice('')))}
          setAll={(choices: ActivityTypes.Choice[]) =>
            dispatch(ChoiceActions.setAllChoices(choices))
          }
          onEdit={(id, content) => dispatch(ChoiceActions.editChoiceContent(id, content))}
          onRemove={(id) => dispatch(Actions.removeChoice(id))}
        />
      </TabbedNavigation.Tab>
      <TabbedNavigation.Tab label="Answer Key">
        <OrderingChoices
          choices={model.choices}
          setChoices={(choices) => dispatch(ChoiceActions.setAllChoices(choices))}
        />
        <SimpleFeedback
          correctResponse={getCorrectResponse(model)}
          incorrectResponse={getIncorrectResponse(model)}
          update={(id, content) => dispatch(ResponseActions.editResponseFeedback(id, content))}
        />
        {isTargetedOrdering(model) &&
          getTargetedResponseMappings(model).map((mapping) => (
            <ResponseCard
              title="Targeted feedback"
              response={mapping.response}
              updateFeedback={(id, content) =>
                dispatch(ResponseActions.editResponseFeedback(mapping.response.id, content))
              }
              onRemove={(id) => dispatch(ResponseActions.removeResponse(id))}
              key={mapping.response.id}
            >
              <OrderingChoices
                choices={mapping.choiceIds.map((id) => getChoice(model, id))}
                setChoices={(choices) =>
                  dispatch(
                    Actions.editTargetedFeedbackChoices(
                      mapping.response.id,
                      choices.map((c) => c.id),
                    ),
                  )
                }
              />
            </ResponseCard>
          ))}
        <AuthoringButtonConnected
          className="align-self-start btn btn-link"
          action={() => dispatch(Actions.addTargetedFeedback())}
        >
          Add targeted feedback
        </AuthoringButtonConnected>
      </TabbedNavigation.Tab>
      <TabbedNavigation.Tab label="Hints">
        <HintsAuthoringConnected hintsPath="$.authoring.parts[0].hints" />
      </TabbedNavigation.Tab>
      <ActivitySettings
        settings={[
          shuffleAnswerChoiceSetting(model, dispatch),
          {
            isEnabled: isTargetedOrdering(model),
            label: 'Targeted feedback',
            onToggle: () => dispatch(Actions.toggleType()),
          },
        ]}
      />
    </TabbedNavigation.Tabs>
  );
};

export class OrderingAuthoring extends AuthoringElement<OrderingModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<OrderingModelSchema>) {
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
