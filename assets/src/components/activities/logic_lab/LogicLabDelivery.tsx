/*
React web component for delivering LogicLab based activities in Torus.

This is designed to run the LogicLab in an iframe and handles the
communication between the LogicLab and Torus.
*/
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector, useStore } from 'react-redux';
import { ScoreAsYouGoHeaderBase } from 'components/activities/common/ScoreAsYouGoHeader';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
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
import { castPartId } from '../common/utils';
import { Manifest } from '../types';
import {
  LabActivity,
  LogicLabModelSchema,
  LogicLabSaveState,
  isLabActivity,
  isLabMessage,
  useLabServer,
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
  const [activity, setActivity] = useState<string | LabActivity>(model.activity);
  const [instanceId] = useState<string>(crypto.randomUUID().slice(0, 8));
  const [isResetting, setIsResetting] = useState(false);
  const [loading, setLoading] = useState<'loading' | 'loaded' | 'error'>('loading');
  const [baseUrl, setBaseUrl] = useState<string>('');
  const labServer = useLabServer(context);

  useEffect(() => {
    // Standard one-time listener setup for all torus activities
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity, { [partId]: [''] });
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    // when using uiState: ActivityDeliveryState from the Redux store, the first render
    // is used to initialize the saved PartInputs from the incoming activityState,
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

  // Code must be safe against undefined partStates during first render.
  const attemptState = uiState.attemptState;
  const currentPart = attemptState?.parts?.[0];

  const getStoredInput = useCallback(
    (state: ActivityDeliveryState, partId: string, part: typeof currentPart) =>
      state.partState?.[partId]?.studentInput?.[0] ?? ensureStr(part?.response?.input),
    [],
  );

  const onMessage = useCallback(
    async (e: MessageEvent) => {
      if (!labServer) {
        return;
      }
      try {
        const lab = new URL(labServer);
        const origin = new URL(e.origin);
        // filter so we do not process torus events.
        if (origin.host === lab.host) {
          const msg = e.data;
          // only lab messages from this activity for handling multiple problems on a page.
          // Parameter is named "attemptGuid" but it is just a unique instance id.
          if (isLabMessage(msg) && msg.attemptGuid === instanceId) {
            // Lab will not send messages until initialized by next hook, so we can be sure
            // attempt state in Redux store has been initialized. Fetching state as needed
            // from store here avoids having to worry about closure over uiState going stale
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
                    const existingInput = getStoredInput(state, currentPartId, part);
                    const payloadChanged = serializedInput !== existingInput;
                    // We don't have a concept of "selection", but setSelection action works to
                    // update the student input in the store and save to server
                    if (payloadChanged) {
                      await dispatch(
                        setSelection(currentPartId, serializedInput, onSaveActivity, 'single'),
                      );
                    }
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
                    setIsResetting(true);
                    await dispatch(
                      resetAction(onResetActivity, { [currentPartId]: [serializedInput] }),
                    );
                    setIsResetting(false);

                    const updatedAttempt = store.getState().attemptState;
                    const updatedPart =
                      updatedAttempt.parts.find((p) => castPartId(p.partId) === currentPartId) ||
                      updatedAttempt.parts[0];

                    // Save immediately to carry forward input into new attempt
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
                  // don't save while reset in process, or if already evaluated.
                  if (isResetting || part.dateEvaluated) break;

                  const serializedInput = JSON.stringify(msg.state);
                  const existingInput = getStoredInput(state, currentPartId, part);
                  if (serializedInput === existingInput) break;
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
                if (e.source) {
                  const payload: Record<string, unknown> = {};

                  if (activity) {
                    payload.activity = activity;
                  }

                  const savedInput =
                    mode !== 'preview'
                      ? state.partState?.[currentPartId]?.studentInput?.[0]
                      : undefined;

                  const fallbackInput =
                    ['delivery', 'review'].includes(mode) && !savedInput
                      ? activityState?.parts[0]?.response?.input
                      : undefined;

                  const rawInput = savedInput ?? fallbackInput;
                  if (rawInput) {
                    payload.save = rawInput;
                    try {
                      const labState: LogicLabSaveState =
                        typeof rawInput === 'string' ? JSON.parse(rawInput) : rawInput;
                      payload.state = labState;
                    } catch (parseErr) {
                      console.error('Failed to parse saved LogicLab state', parseErr);
                    }
                  }

                  payload.attemptGuid = instanceId;
                  e.source.postMessage(payload, { targetOrigin: lab.origin });
                }
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
      activity,
      activityState,
      dispatch,
      getStoredInput,
      instanceId,
      isResetting,
      labServer,
      mode,
      model.feedback,
      onResetActivity,
      onSaveActivity,
      onSubmitEvaluations,
      store,
    ],
  );

  useEffect(() => {
    window.addEventListener('message', onMessage);

    return () => window.removeEventListener('message', onMessage);
  }, [onMessage]);

  useEffect(() => {
    setLoading('loading');

    if (!labServer) {
      setBaseUrl('');
      return;
    }

    try {
      if (!activity) {
        throw new Error('LogicLab activity is not configured. Please contact the course author.');
      }

      const url = new URL(labServer);
      url.searchParams.set('mode', mode);
      url.searchParams.set('attemptGuid', instanceId);

      if (!isLabActivity(activity)) {
        url.searchParams.set('activity', activity);
      }

      setBaseUrl(url.toString());
      setLoading('loaded');
    } catch (err) {
      console.error(err);
      setBaseUrl('');
      setLoading('error');
    }
  }, [activity, instanceId, labServer, mode]);

  // first render is just to initialize state
  if (!uiState.partState || !attemptState || !currentPart) {
    return null;
  }

  return (
    <>
      {loading === 'loading' && (
        <div className="alert alert-warning" role="alert">
          Configuring LogicLab... If this message persists, please contact the system administrator.
        </div>
      )}
      {loading === 'error' && (
        <div className="alert alert-danger" role="alert">
          The LogicLab server is unreachable or not properly configured. Please contact support if
          this issue persists.
        </div>
      )}
      {loading === 'loaded' && baseUrl && (
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
            className="mb-3 rounded inset-shadow-sm min-w-[1024px] min-h-[756px] w-full"
            src={baseUrl}
            allow="fullscreen"
            data-oli-activity-mode={mode}
            data-oli-attempt-guid={instanceId}
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
