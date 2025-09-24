/*
React web component for delivering LogicLab based activities in Torus.

This is designed to run the LogicLab in an iframe and handles the
communication between the LogicLab and Torus.
*/
import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch } from 'react-redux';
import { ScoreAsYouGoHeaderBase } from 'components/activities/common/ScoreAsYouGoHeader';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import {
  activityDeliverySlice,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
} from 'data/activities/DeliveryState';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { Manifest } from '../types';
import {
  LabActivity,
  LogicLabModelSchema,
  isLabActivity,
  isLabMessage,
  useLabServer,
} from './LogicLabModelSchema';

type LogicLabDeliveryProps = DeliveryElementProps<LogicLabModelSchema>;

/**
 * LogicLab delivery component shell.
 * Sets up the iframe and message event handler to deal with
 * message events from the lab activity.
 * @component
 */
const LogicLab: React.FC<LogicLabDeliveryProps> = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onSubmitEvaluations,
    onSaveActivity,
    onResetActivity,
    onResetPart,
    model,
    mode,
  } = useDeliveryElementContext<LogicLabModelSchema>();
  const dispatch = useDispatch();
  const [activity, setActivity] = useState<string | LabActivity>(model.activity);
  const labServer = useLabServer(context);

  useEffect(() => {
    // This looks like boilerplate code for dealing with embedded activities.
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity);
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    setActivity(model.activity);
    let partGuid = activityState.parts[0].attemptGuid; // Moving to higher scope which helps state saving to work.

    const onMessage = async (e: MessageEvent) => {
      if (!labServer) return; // lab server not set, so ignore messages.
      try {
        const lab = new URL(labServer);
        const origin = new URL(e.origin);
        // filter so we do not process torus events.
        if (origin.host === lab.host) {
          const msg = e.data;
          // only lab messages from this activity for eventual support of multiple problems on a page.
          if (isLabMessage(msg) && msg.attemptGuid === activityState.attemptGuid) {
            const attemptGuid = activityState.attemptGuid;
            switch (msg.messageType) {
              // respond to lab score request.
              case 'score':
                if (mode === 'delivery') {
                  // only when in delivery
                  try {
                    // .dateEvaluated seems to not work as a check to see if part is evaluatable
                    // Always resetting and saving seems to fix the issue with a second attempt
                    // not registering grading.
                    // if (activityState.parts[0].dateEvaluated) {
                    // if the part has already been evaluated, then
                    // it is necessary to reset the part to get a new
                    // partGuid as there can only ever be one evaluation
                    // per partGuid.
                    const partResponse = await onResetPart(attemptGuid, partGuid);
                    partGuid = partResponse.attemptState.attemptGuid;
                    // import state to new part, luckily the current state
                    // is already included in the score message so no need
                    // to maintain it in state.
                    await onSaveActivity(attemptGuid, [
                      {
                        attemptGuid: partGuid,
                        response: { input: msg.score.input },
                      },
                    ]);
                    onSubmitEvaluations(attemptGuid, [
                      {
                        score: msg.score.score,
                        outOf: msg.score.outOf,
                        feedback: model.feedback[Number(msg.score.complete)],
                        response: { input: msg.score.input },
                        attemptGuid: partGuid,
                      },
                    ]);
                  } catch (err) {
                    console.error(err);
                  }
                }
                break;
              // respond to lab request to save state.
              case 'save':
                // it seems to only save/restore properly with score
                if (mode === 'delivery') {
                  // only update in delivery mode.
                  try {
                    await onSaveActivity(attemptGuid, [
                      {
                        attemptGuid: partGuid,
                        response: {
                          input: msg.state,
                        },
                      },
                    ]);
                  } catch (err) {
                    console.error(err);
                  }
                }
                break;
              // lab is requesting activity state
              case 'load':
                const save = ['delivery', 'review'].includes(mode)
                  ? activityState?.parts[0].response?.input
                  : undefined;
                e.source?.postMessage({ activity, save }, { targetOrigin: lab.origin });
                break;
              case 'log':
                // Currently logging to console, TODO link into torus/oli logging
                console.log(msg.content);
                break;
              default:
                console.warn('Unknown message type, skipped...', e);
            }
          }
        }
      } catch (err) {
        console.error(err);
      }
    };
    window.addEventListener('message', onMessage);

    return () => window.removeEventListener('message', onMessage);
  }, [activityState, model, labServer]);

  const [baseUrl, setBaseUrl] = useState<string>('');
  useEffect(() => {
    if (!labServer) {
      return;
    }
    if (!activity) {
      throw new Error(
        'LogicLab activity is not configured.  Please contact the course author for assistance.',
      );
    }
    // If the activity is a LabActivity, then use message passing to get the activity configuration.
    // Otherwise, use the activity ID to get the configuration from the logiclab server.
    const url = new URL(labServer);
    url.searchParams.append('mode', mode);
    url.searchParams.append('attemptGuid', activityState.attemptGuid);
    if (!isLabActivity(activity)) {
      // if activity is a string, then it is the activity id and should be passed as such.
      // Possible extension would be to fetch the activity in the load message handler.
      url.searchParams.append('activity', activity);
    }
    setBaseUrl(url.toString());
  }, [activity, mode, activityState, labServer]);

  return !baseUrl ? (
    <LoadingSpinner />
  ) : (
    <div>
      <ScoreAsYouGoHeaderBase
        batchScoring={context.batchScoring}
        graded={context.graded}
        ordinal={context.ordinal}
        maxAttempts={context.maxAttempts}
        attemptNumber={activityState.attemptNumber}
      />
      <iframe
        title={`LogicLab Activity ${model.context?.title}`}
        src={baseUrl}
        allow="fullscreen"
        height="800"
        width="100%"
        // data attributes only work if same-site, so using message passing instead.
        data-oli-activity-mode={mode}
        // data-logiclab-activity={JSON.stringify(activity)} // use message passing instead of data attribute.
        data-oli-attempt-guid={activityState.attemptGuid}
      ></iframe>
    </div>
  );
};

/**
 * Torus Delivery component for LogicLab activities.
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
          <ErrorBoundary>
            <LogicLab {...props} />
          </ErrorBoundary>
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json') as Manifest;
// Register component as a web component.
window.customElements.define(manifest.delivery.element, LogicLabDelivery);
