import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { ShortAnswerModelSchema } from './schema';
import { ShortAnswerActions } from './actions';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';
import { containsRule, eqRule, parseInputFromRule } from 'data/activities/model/rules';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { getCorrectResponse } from 'data/activities/model/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { InputTypeDropdown } from 'components/activities/common/authoring/InputTypeDropdown';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { getTargetedResponses, shortAnswerOptions } from 'components/activities/short_answer/utils';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { makeResponse, Manifest, Response } from 'components/activities/types';
import { hintsByPart } from 'data/activities/model/hintUtils';

const store = configureStore();

const ShortAnswer = () => {
  const { dispatch, model, editMode } = useAuthoringElementContext<ShortAnswerModelSchema>();
  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="d-flex flex-column flex-md-row mb-2">
            <Stem />
            <InputTypeDropdown
              options={shortAnswerOptions}
              editMode={editMode}
              selected={model.inputType}
              onChange={(inputType) =>
                dispatch(
                  ShortAnswerActions.setInputType(
                    inputType,
                    parseInputFromRule(getCorrectResponse(model, DEFAULT_PART_ID).rule),
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
              key={getCorrectResponse(model, DEFAULT_PART_ID).id}
              inputType={model.inputType}
              response={getCorrectResponse(model, DEFAULT_PART_ID)}
              onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
            />
            <SimpleFeedback partId={DEFAULT_PART_ID} />
            {getTargetedResponses(model, DEFAULT_PART_ID).map((response: Response) => (
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
                  inputType={model.inputType}
                  response={response}
                  onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
                />
              </ResponseCard>
            ))}
            <AuthoringButtonConnected
              className="align-self-start btn btn-link"
              action={() =>
                dispatch(
                  ResponseActions.addResponse(
                    makeResponse(
                      model.inputType === 'numeric' ? eqRule('1') : containsRule('another answer'),
                      0,
                      '',
                    ),
                    DEFAULT_PART_ID,
                  ),
                )
              }
            >
              Add targeted feedback
            </AuthoringButtonConnected>
          </div>
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints hintsByPart={hintsByPart(DEFAULT_PART_ID)} partId={DEFAULT_PART_ID} />
        </TabbedNavigation.Tab>
        <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
      </TabbedNavigation.Tabs>
    </>
  );
};

export class ShortAnswerAuthoring extends AuthoringElement<ShortAnswerModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ShortAnswerModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ShortAnswer />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, ShortAnswerAuthoring);
