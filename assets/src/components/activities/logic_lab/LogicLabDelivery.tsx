import { activityDeliverySlice, listenForParentSurveyReset, listenForParentSurveySubmit, listenForReviewAttemptChange } from "data/activities/DeliveryState";
import React, { useEffect } from "react";
import ReactDOM from "react-dom";
import { Provider, useDispatch } from "react-redux";
import { configureStore } from "state/store";
import { DeliveryElement, DeliveryElementProps } from "../DeliveryElement";
import { DeliveryElementProvider, useDeliveryElementContext } from "../DeliveryElementProvider";
import { Manifest } from "../types";
import { LogicLabModelSchema, isLabMessage } from "./LogicLabModelSchema";

/**
 * LogicLab delivery component shell.
 * Sets up the iframe and message event handler to deal with
 * message events from the lab activity.
 * @component
 */
const LogicLab: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onSubmitEvaluations,
    onSaveActivity,
    onResetActivity,
    model,
    mode
  } = useDeliveryElementContext<LogicLabModelSchema>();
  const dispatch = useDispatch();
  const activity = activityState.parts[0].partId;

  useEffect(() => {
    // This looks like boilerplate code for dealing with embedded activities.
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity, {
      [activityState.parts[0].partId]: [],
    });
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    const onMessage = async (e: MessageEvent) => {
      const msg = e as MessageEvent;
      const lab = new URL(model.src);
      const origin = new URL(msg.origin);
      // filter so we do not process torus events.
      if (origin.host === lab.host) {
        // console.log('message event', e);
        const msg = e.data;
        if (isLabMessage(msg)) {
          const attemptGuid = activityState.attemptGuid;
          const partGuid = activityState.parts[0].attemptGuid;
          switch (msg.messageType) {
            // respond to lab score request.
            case 'score':
              if (mode === 'delivery') { // only when in delivery
                console.log('scoring...');
                try {
                  onSubmitEvaluations(attemptGuid, [{
                    score: msg.score.score,
                    outOf: msg.score.outOf,
                    feedback: null,
                    response: msg.score.response,
                    attemptGuid: partGuid,
                  }]); // FIXME
                } catch (err) {
                  console.error(err);
                }
              }
              break;
            // respond to lab request to save state.
            case 'save':
              if (mode === 'delivery') { // only update in delivery mode.
                try {
                  await onSaveActivity(attemptGuid, [{
                    attemptGuid: partGuid,
                    response: {
                      input: msg.state,
                    }
                  }]);
                } catch (err) {
                  console.error(err);
                }
              }
              break;
            // lab is requesting activity state
            case 'load':
              if (mode !== 'preview') {
                const saved = activityState?.parts[0].response?.input;
                if (saved && e.source) {
                  // post saved state back to lab.
                  e.source.postMessage(saved, { targetOrigin: model.src });
                }
              } // TODO if in preview, load appropriate content
              // Preview featrue in lab servlet is not complete.
              break;
            case 'log':
              // Currenly logging to console, TODO link into torus/oli logging
              // console.log(msg.content);
              break;
            default:
              console.warn('Unknown message type, skipped...', e);
          }
        }
      }
    }
    window.addEventListener('message', onMessage);

    return () => window.removeEventListener('message', onMessage);
  }, [activityState, model]);

  return (
    <iframe
      src={`${model.src}${activity};mode=${mode}`}
      allowFullScreen={true}
      height="800"
      width="100%"
      data-activity-mode={mode}
    ></iframe>
  )
}

/** Torus Delivery component for the LogicLab
 * @component
 */
export class LogicLabDelivery extends DeliveryElement<LogicLabModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<LogicLabModelSchema>): void {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'LogicLabDelivery',
    });
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <LogicLab />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    )
  }
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json') as Manifest;
// Register component as a web component.
window.customElements.define(manifest.delivery.element, LogicLabDelivery);
