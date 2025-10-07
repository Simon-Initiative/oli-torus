/*
React web component for delivering LogicLab based activities in Torus.

This is designed to run the LogicLab in an iframe and handles the
communication between the LogicLab and Torus.
*/
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector, useStore } from 'react-redux';
import {
  ActivityDeliveryState,
  PartInputs,
  activityDeliverySlice,
  initializeState,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  resetAction,
  setSelection,
} from 'data/activities/DeliveryState';
import { safelySelectStringInputs } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { ScoreAsYouGoHeaderBase } from '../common/ScoreAsYouGoHeader';
import { castPartId } from '../common/utils';
import { Manifest } from '../types';
import {
  LogicLabModelSchema,
  LogicLabSaveState,
  getLabServer,
  isLabMessage,
} from './LogicLabModelSchema';

type LogicLabDeliveryProps = DeliveryElementProps<LogicLabModelSchema>;

// These helpers handle case of old-version saves which stored input as objects
// rather than strings
const ensureStr = (input: unknown): string => {
  if (input === undefined || input === null) {
    return '';
  }
  return typeof input === 'string' ? input : JSON.stringify(input);
};

const normalizePartInputs = (inputs: PartInputs): PartInputs =>
  Object.entries(inputs).reduce((acc, [partId, values]) => {
    const normalized = ensureStr(values?.[0]);
    acc[partId] = normalized ? [normalized] : [''];
    return acc;
  }, {} as PartInputs);

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
  const store = useStore<ActivityDeliveryState>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const partId = castPartId(activityState.parts[0].partId);
  const [activity, setActivity] = useState<string>(model.activity);
  const [instanceId] = useState<string>(crypto.randomUUID().slice(0, 8));

  useEffect(() => {
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity, { [partId]: [''] });
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    // when using uiState: ActivityDeliveryState in the Redux store, the first render
    // must initialize the saved PartInputs from the incoming activityState,
    // allowing for them to be undefined as happens for a never saved activity.
    const initialInputs = safelySelectStringInputs(activityState).caseOf({
      just: (inputs) => normalizePartInputs(inputs),
      // no saved input in activityState; start with empty string placeholder
      nothing: () => ({ [partId]: [''] }),
    });

    dispatch(initializeState(activityState, initialInputs, model, context));
  }, []);

  useEffect(() => setActivity(model.activity), [model.activity]);
  useEffect(() => {
    if (uiState?.model) {
      setActivity((uiState.model as LogicLabModelSchema).activity);
    }
  }, [uiState.model]);

  // Code must guard against undefined partStates during first render.
  const attemptState = uiState.attemptState;
  const currentPart = attemptState?.parts?.[0];
  const currentPartId = currentPart ? castPartId(currentPart.partId) : partId;
  const storedInput =
    uiState.partState?.[currentPartId]?.studentInput?.[0] ??
    ensureStr(activityState.parts[0]?.response?.input);
  const attemptGuid = attemptState?.attemptGuid ?? activityState.attemptGuid;
  const partAttemptGuid = currentPart?.attemptGuid ?? activityState.parts[0].attemptGuid;
  if (attemptState && currentPart) {
    console.log(
      `LogicLabDelivery[${instanceId}] render attemptGuid=${attemptGuid} partGuid=${partAttemptGuid} input(${typeof storedInput})=${storedInput})`,
    );
  }

  const onMessage = useCallback(
    async (e: MessageEvent) => {
      try {
        const lab = new URL(getLabServer(context));
        const origin = new URL(e.origin);
        // filter so we do not process torus events.
        if (origin.host === lab.host) {
          const msg = e.data;
          console.log(`got lab msg[${msg.attemptGuid}]: ${msg.messageType}`);
          // only lab messages from this activity for handling multiple problems on a page.
          // Parameter is named "attemptGuid" but it is just a unique instance id.
          if (isLabMessage(msg) && msg.attemptGuid === instanceId) {
            // Lab will not send messages until initialized by next hook, so we
            // can be sure uiState is initialized
            const state = store.getState();
            const attempt = state.attemptState;
            const part = attempt.parts[0];
            const currentPartId = castPartId(part.partId);
            switch (msg.messageType) {
              // respond to lab score request.
              case 'score':
                if (mode === 'delivery') {
                  try {
                    const serializedInput = JSON.stringify(msg.score.input);
                    console.log(
                      `Submitting evaluation attemptGuid=${attempt.attemptGuid} partGuid=${part.attemptGuid} ${msg.score.score}/${msg.score.outOf} input=${serializedInput}}`,
                    );
                    // We don't have a concept of "selection", but setSelection action works to
                    // update the student input in the store and save to server
                    await dispatch(
                      setSelection(currentPartId, serializedInput, onSaveActivity, 'single'),
                    );
                    await onSubmitEvaluations(attempt.attemptGuid, [
                      {
                        score: msg.score.score,
                        outOf: msg.score.outOf,
                        feedback: model.feedback[Number(msg.score.complete)],
                        response: { input: serializedInput },
                        attemptGuid: part.attemptGuid,
                      },
                    ]);
                    // Submitting evaluation finalizes current activity attempt. Automatically
                    // reset activity to get new attempt for subsequent work. Lab may have sent an
                    // intermediate score on an incomplete problem, but a series of attempts is
                    // needed to make Best scoring strategy work as desired on ScoreAsYouGo pages,
                    // since that strategy is applied over finalized activity attempts
                    console.log('resetting activity');
                    await dispatch(
                      resetAction(onResetActivity, { [currentPartId]: [serializedInput] }),
                    );

                    const updatedAttempt = store.getState().attemptState;
                    const updatedPart =
                      updatedAttempt.parts.find((p) => castPartId(p.partId) === currentPartId) ||
                      updatedAttempt.parts[0];
                    console.log(
                      `After resetActivity => new attemptGuid=${updatedAttempt.attemptGuid} partGuid=${updatedPart.attemptGuid}`,
                    );
                    // Save immediately to carry forward input into new attempt
                    console.log('saving input into new attempt ');
                    await dispatch(
                      setSelection(
                        castPartId(updatedPart.partId),
                        serializedInput,
                        onSaveActivity,
                        'single',
                      ),
                    );
                  } catch (err) {
                    console.error(err);
                  }
                }
                break;
              // respond to lab request to save state.
              case 'save':
                if (mode === 'delivery') {
                  const serializedInput = JSON.stringify(msg.state);
                  console.log(
                    `saving attemptGuid=${attempt.attemptGuid} partGuid=${part.attemptGuid} input=${serializedInput}`,
                  );
                  try {
                    await dispatch(
                      setSelection(currentPartId, serializedInput, onSaveActivity, 'single'),
                    );
                  } catch (err) {
                    console.error(err);
                  }
                }
                break;
              // lab is requesting activity state
              case 'load':
                if (mode !== 'preview') {
                  const savedInput =
                    state.partState?.[currentPartId]?.studentInput?.[0] ??
                    ensureStr(part.response?.input);
                  console.log(`found saved response= ${savedInput}`);
                  if (savedInput && e.source) {
                    // post saved state back to lab.
                    console.log('posting saved state back to lab');
                    try {
                      const labState: LogicLabSaveState =
                        typeof savedInput === 'string' ? JSON.parse(savedInput) : savedInput;
                      e.source.postMessage(labState, { targetOrigin: lab.origin });
                    } catch (parseErr) {
                      console.error('Failed to parse saved LogicLab state', parseErr);
                    }
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
    [
      activityState,
      context,
      dispatch,
      instanceId,
      mode,
      model.feedback,
      onResetActivity,
      onSaveActivity,
      onSubmitEvaluations,
      store,
    ],
  );

  useEffect(() => {
    console.log(`updating msg handler with attemptGuid=${attemptGuid} partGuid=${partAttemptGuid}`);
    window.addEventListener('message', onMessage);

    return () => window.removeEventListener('message', onMessage);
  }, [attemptGuid, onMessage, partAttemptGuid]);

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

  // first render is just to initialize state
  if (!uiState.partState || !attemptState || !currentPart) {
    return null;
  }

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
            // set batchScoring in all cases to suppress attempt number because it is meaningless
            // to students in LogicLab intended use with ScoreAsYouGo. Will show question ordinal.
            batchScoring={true}
            graded={context.graded}
            ordinal={context.ordinal}
            maxAttempts={context.maxAttempts}
            attemptNumber={attemptState.attemptNumber}
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
