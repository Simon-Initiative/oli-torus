/*
React web component for delivering LogicLab based activities in Torus.

This is designed to run the LogicLab in an iframe and handles the
communication between the LogicLab and Torus.
*/
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch } from 'react-redux';
import { ScoreAsYouGoHeaderBase } from 'components/activities/common/ScoreAsYouGoHeader';
import {
  activityDeliverySlice,
  initializeState,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  resetAction,
} from 'data/activities/DeliveryState';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { Manifest } from '../types';
import { LogicLabModelSchema, getLabServer, isLabMessage } from './LogicLabModelSchema';

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
    model,
    mode,
  } = useDeliveryElementContext<LogicLabModelSchema>();
  const dispatch = useDispatch();
  const [activity, setActivity] = useState<string>(model.activity);
  // unique instance id used to distinguish lab messages from different problems on page
  const [instanceId] = useState<string>(crypto.randomUUID().slice(0, 8));
  // Most torus components use Redux-store-based state management using an
  // ActivityDeliveryState object, updating via actions that trigger server
  // API calls and update store with results. We do direct API calls without that
  // machinery, and incoming activity state from context is apparently only valid
  // on activity startup, not automatically updated on results when called this way.
  // So we track the changing activity state here in local state variables.
  type LocalActivityState = {
    attemptGuid: string;
    partGuid: string;
    response: string;
  };
  const [localActivityState, setLocalActivityState] = useState<LocalActivityState>({
    attemptGuid: activityState.attemptGuid,
    partGuid: activityState.parts[0].attemptGuid,
    response: activityState.parts[0].response,
  });
  const attemptGuid = localActivityState.attemptGuid;
  const partGuid = localActivityState.partGuid;
  const response = localActivityState.response;
  console.log(
    `LogicLabDelivery[${instanceId}] render attemptGuid=${attemptGuid} partGuid=${partGuid} response=${JSON.stringify(
      response,
    )}`,
  );

  useEffect(() => {
    // one-time listener setup used for all embedded activities
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity);
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);
  }, []);

  useEffect(() => setActivity(model.activity), [model.activity]);

  const onMessage = useCallback(
    async (e: MessageEvent) => {
      // utility for console messages
      const abbr = (s: any) => (s ? JSON.stringify(s).slice(0, 32) + '...' : s);
      try {
        const lab = new URL(getLabServer(context));
        const origin = new URL(e.origin);
        // filter so we do not process torus events.
        if (origin.host === lab.host) {
          const msg = e.data;
          console.log(`got lab msg[${msg.attemptGuid}]: ${msg.messageType}`);
          // only lab messages from this activity for handling multiple problems on a page.
          // NB parameter is named "attemptGuid" but it is now just a unique instance id.
          if (isLabMessage(msg) && msg.attemptGuid === instanceId) {
            switch (msg.messageType) {
              // respond to lab score request.
              case 'score':
                if (mode === 'delivery') {
                  try {
                    console.log(
                      `Submitting evaluation  attemptGuid=${attemptGuid} partGuid=${partGuid} ${
                        msg.score.score
                      }/${msg.score.outOf} response=${JSON.stringify(msg.score.input)}}`,
                    );
                    await onSubmitEvaluations(attemptGuid, [
                      {
                        score: msg.score.score,
                        outOf: msg.score.outOf,
                        feedback: model.feedback[Number(msg.score.complete)],
                        response: { input: msg.score.input },
                        attemptGuid: partGuid,
                      },
                    ]);
                    // Submitting evaluation finalizes current activity attempt. Automatically
                    // reset activity to get new attempt for subsequent work. Lab may have sent an
                    // intermediate score on an incomplete problem, but a series of attempts is
                    // needed to make Best scoring strategy work as desired on ScoreAsYouGo pages,
                    // since that strategy is applied over finalized activity attempts
                    console.log('resetting activity');
                    const { attemptState: newAttemptState } = await onResetActivity(attemptGuid);
                    const newAttemptGuid = newAttemptState.attemptGuid;
                    const newPartGuid = newAttemptState.parts[0].attemptGuid;
                    console.log(
                      `After resetActivity => new attemptGuid=${newAttemptGuid} partGuid=${newPartGuid}`,
                    );
                    // save immediately so state to carry state over into new attempt
                    console.log('saving input into new attempt ');
                    await onSaveActivity(newAttemptGuid, [
                      {
                        attemptGuid: newPartGuid,
                        response: {
                          input: msg.score.input,
                        },
                      },
                    ]);
                    // msg handler now a stale closure holding old attemptGuid/partGuid
                    // state change forces re-render to re-run effect hook to update
                    setLocalActivityState({
                      attemptGuid: newAttemptGuid,
                      partGuid: newPartGuid,
                      response: msg.score.input as string,
                    });
                  } catch (err) {
                    console.error(err);
                  }
                }
                break;
              // respond to lab request to save state.
              case 'save':
                if (mode === 'delivery') {
                  console.log(
                    `saving attemptGuid=${attemptGuid} partGuid=${partGuid} response=${JSON.stringify(
                      msg.state,
                    )}`,
                  );
                  try {
                    await onSaveActivity(attemptGuid, [
                      {
                        attemptGuid: partGuid,
                        response: {
                          input: msg.state,
                        },
                      },
                    ]);
                    // update stored response in our state
                    localActivityState.response = msg.state as string;
                    setLocalActivityState(localActivityState);
                  } catch (err) {
                    console.error(err);
                  }
                }
                break;
              // lab is requesting activity state
              case 'load':
                if (mode !== 'preview') {
                  console.log(`found saved response= ${JSON.stringify(response)}`);
                  if (response && e.source) {
                    // post saved state back to lab.
                    console.log('posting saved state back to lab');
                    e.source.postMessage(response, { targetOrigin: lab.origin });
                  }
                } // TODO if in preview, load appropriate content
                // Preview feature in lab servlet is not complete.
                break;
              case 'log':
                // Currently logging to console, TODO link into torus/oli logging
                console.log('log:' + msg.content);
                break;
              default:
                console.warn('Unknown message type, skipped...', e);
            }
          }
        }
      } catch (err) {
        console.error(err);
      }
    },
    [localActivityState],
  );

  useEffect(() => {
    console.log(`updating msg handler with attemptGuid=${attemptGuid} partGuid=${partGuid}`);
    window.addEventListener('message', onMessage);

    return () => window.removeEventListener('message', onMessage);
  }, [onMessage]);

  const [loading, setLoading] = useState<'loading' | 'loaded' | 'error'>('loading');
  const [baseUrl, setBaseUrl] = useState<string>('');
  useEffect(() => {
    const controller = new AbortController();
    const signal = controller.signal;
    try {
      const server = getLabServer(context);
      const url = new URL(`api/v1/activities/lab/${activity}`, server);
      url.searchParams.append('activity', activity);
      url.searchParams.append('mode', mode);
      url.searchParams.append('attemptGuid', instanceId);
      // only update in delivery mode.
      console.log(`[${instanceId}] initializing lab with problem ${activity} mode ${mode}`);
      // Using promise because react's useEffect does not handle async.
      // toString because tsc does not accept the valid URL.
      fetch(url.toString(), { signal, method: 'HEAD' })
        .then((response) => {
          if (!response.ok) {
            throw new Error(response.statusText);
          }
          setLoading('loaded');
          setBaseUrl(url.toString());
        })
        .catch(() => setLoading('error'));
    } catch (err) {
      console.error(err);
      setLoading('error');
    }
    return () => controller.abort();
  }, [activity, mode]);

  return (
    <>
      {loading === 'loading' && (
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden sr-only">Loading...</span>
        </div>
      )}
      {loading === 'error' && (
        <div className="alert alert-danger">
          The LogicLab server is unreachable or not properly configured. Please contact support if
          this issue persists.
        </div>
      )}
      {loading === 'loaded' && (
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
            data-activity-mode={mode}
          ></iframe>
        </div>
      )}
    </>
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
          <LogicLab {...props} />
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
