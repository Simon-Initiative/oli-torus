import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { ShortAnswerModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { ShortAnswerActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';
import { parseInputFromRule } from 'components/activities/common/responses/authoring/rules';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { getCorrectResponse } from 'components/activities/common/responses/authoring/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { InputTypeDropdown } from 'components/activities/short_answer/sections/InputTypeDropdown';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { getTargetedResponses } from 'components/activities/short_answer/utils';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';

const store = configureStore();

const ShortAnswer = (props: AuthoringElementProps<ShortAnswerModelSchema>) => {
  const { dispatch, model } = useAuthoringElementContext<ShortAnswerModelSchema>();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="d-flex flex-column flex-md-row mb-2">
            <Stem />
            <InputTypeDropdown
              editMode={props.editMode}
              inputType={props.model.inputType}
              onChange={(inputType) =>
                dispatch(
                  ShortAnswerActions.setInputType(
                    inputType,
                    parseInputFromRule(getCorrectResponse(props.model).rule),
                  ),
                )
              }
            />
          </div>
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <div className="d-flex flex-column mb-2">
            <StemDelivery stem={model.stem} context={defaultWriterContext()} />
            <InputEntry
              key={getCorrectResponse(props.model).id}
              inputType={props.model.inputType}
              response={getCorrectResponse(props.model)}
              onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
            />
            <SimpleFeedback />
            {getTargetedResponses(props.model).map((response: ActivityTypes.Response) => (
              <ResponseCard
                title="Targeted feedback"
                response={response}
                updateFeedback={(id, content) =>
                  dispatch(ResponseActions.editResponseFeedback(response.id, content))
                }
                onRemove={(id) => dispatch(ResponseActions.removeResponse(id))}
                key={response.id}
              >
                <InputEntry
                  key={response.id}
                  inputType={props.model.inputType}
                  response={response}
                  onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
                />
              </ResponseCard>
            ))}
            <AuthoringButtonConnected
              className="align-self-start btn btn-link"
              action={() => dispatch(ShortAnswerActions.addResponse())}
            >
              Add targeted feedback
            </AuthoringButtonConnected>
          </div>
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints hintsPath="$.authoring.parts[0].hints" />
        </TabbedNavigation.Tab>
        <ActivitySettings settings={[shuffleAnswerChoiceSetting(props.model, dispatch)]} />
      </TabbedNavigation.Tabs>
    </>
  );
};

export class ShortAnswerAuthoring extends AuthoringElement<ShortAnswerModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ShortAnswerModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ShortAnswer {...props} />
        </AuthoringElementProvider>
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, ShortAnswerAuthoring);
