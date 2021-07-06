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
import { HintsAuthoringConnected } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';
import { parseInputFromRule } from 'components/activities/common/responses/authoring/rules';
import { StemAuthoringConnected } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { InputTypeDropdown } from 'components/activities/short_answer/sections/InputTypeDropdown';
import { Card } from 'components/misc/Card';
import { Tooltip } from 'components/misc/Tooltip';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import {
  saGetIncorrectResponse,
  saGetTargetedResponses,
} from 'components/activities/short_answer/utils';

const store = configureStore();

const ShortAnswer = (props: AuthoringElementProps<ShortAnswerModelSchema>) => {
  const { dispatch, model } = useAuthoringElementContext<ShortAnswerModelSchema>();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="row mb-2">
            <div className="col-md-8">
              <StemAuthoringConnected />
            </div>
            <div className="col-md-4">
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
            <SimpleFeedback
              correctResponse={getCorrectResponse(props.model)}
              incorrectResponse={saGetIncorrectResponse(props.model)}
              update={(id, content) => dispatch(ResponseActions.editResponseFeedback(id, content))}
            />
            {console.log(getResponses(props.model))}
            {saGetTargetedResponses(props.model).map((response: ActivityTypes.Response) => (
              <Card.Card key={response.id}>
                <Card.Title>
                  <>
                    Targeted Feedback
                    <Tooltip title={'Shown only when a student response matches this answer'} />
                    <RemoveButtonConnected
                      onClick={() => dispatch(ResponseActions.removeResponse(response.id))}
                    />
                  </>
                </Card.Title>
                <Card.Content>
                  <InputEntry
                    key={response.id}
                    inputType={props.model.inputType}
                    response={response}
                    onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
                  />
                  <RichTextEditorConnected
                    style={{ backgroundColor: 'white' }}
                    placeholder="Enter feedback"
                    text={response.feedback.content}
                    onEdit={(content) =>
                      dispatch(ResponseActions.editResponseFeedback(response.id, content))
                    }
                  />
                </Card.Content>
              </Card.Card>
            ))}
            <AuthoringButtonConnected
              className="align-self-start btn btn-link"
              onClick={() => dispatch(ShortAnswerActions.addResponse())}
            >
              Add targeted feedback
            </AuthoringButtonConnected>
          </div>
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <HintsAuthoringConnected hintsPath="" />
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
