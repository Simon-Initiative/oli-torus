import { evalAssignScript, getLocalizedStateSnapshot } from 'adaptivity/scripting';
import { EventEmitter } from 'events';
import { Environment } from 'janus-script';
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import {
  NotificationContext,
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import * as ActivityTypes from '../types';
import PartsLayoutRenderer from './components/delivery/PartsLayoutRenderer';
import { AdaptiveModelSchema } from './schema';

// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;

const sharedInitMap = new Map();
const sharedPromiseMap = new Map();
const sharedAttemptStateMap = new Map();

const Adaptive = (props: DeliveryElementProps<AdaptiveModelSchema>) => {
  const [activityId, setActivityId] = useState<string>(
    props.model?.id || props.model?.activity_id || `unknown_activity`,
  );
  const [mode, setMode] = useState<string>(props.mode);

  const isReviewMode = mode === 'review';

  const [partsLayout, setPartsLayout] = useState(
    props.model.content?.partsLayout || props.model.partsLayout || [],
  );

  const MAX_LISTENERS = 250;
  const [pusher, setPusher] = useState(new EventEmitter().setMaxListeners(MAX_LISTENERS));

  // TODO: this type should be Environment | undefined; this is a local script env for each activity
  // should be provided by the parent as a child env, possibly default to having its own instead
  const [scriptEnv, setScriptEnv] = useState<any>(new Environment());

  const [adaptivityDomain, setAdaptivityDomain] = useState<string>('stage');

  const [init, setInit] = useState<boolean>(false);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (e: any) => {
        /* console.log(`${notificationType.toString()} notification handled [AD]`, e); */
        // here we need to check when the context changes (current activityId) if we are a layer
        // (should only be possible as a layer, because other activities should be unloaded and loaded fresh)
        // layers need to re-init the parts, BUT not re-render them (this is mostly for capi sims)
        // because of the init promise is already resolved with the state snapshot it had the first time
        // the layer rendered, the parts can't simply call init again or they will not get the latest changes
        // still we just currently push notifications straight through, CONTEXT_CHANGED should have the latest snapshot

        if (notificationType === NotificationType.CHECK_COMPLETE) {
          // if the attempt was incorrect, then this will result in a new attempt record being generated
          // if that is the case then the activity and all its parts need to update their guid references
          const attempt = e.attempt;
          const currentAttempt = sharedAttemptStateMap.get(activityId);
          /* console.log('AD CHECK COMPLETE: ', {attempt, currentAttempt, props}); */
          if (
            attempt &&
            currentAttempt &&
            attempt.activityId === currentAttempt.activityId &&
            attempt.attemptGuid !== currentAttempt.attemptGuid
          ) {
            /* console.log(
              `ATTEMPT CHANGING from ${currentAttempt.attemptGuid} to ${attempt.attemptGuid}`,
            ); */
            sharedAttemptStateMap.set(activityId, attempt);
            /* setAttemptState(attempt); */
          }
        }
        pusher.emit(notificationType.toString(), e);
      };
      const unsub = subscribeToNotification(
        props.notify as EventEmitter,
        notificationType,
        handler,
      );
      return unsub;
    });
    return () => {
      /* console.log('AD UNSUB'); */
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify, scriptEnv]);

  useEffect(() => {
    let timeout: NodeJS.Timeout;
    let resolve: any;
    let reject;

    if (!partsLayout.length) {
      if (props.onReady && !isReviewMode) {
        props.onReady(props.state.attemptGuid);
      }
      setInit(true);
      return;
    }

    const partInitWaitLimit = 1000 * 10; // 10 seconds

    const promise = new Promise((res, rej) => {
      let resolved = false;
      resolve = (value: any) => {
        resolved = true;
        res(value);
      };
      reject = (reason: string) => {
        resolved = true;
        rej(reason);
      };
      timeout = setTimeout(() => {
        if (resolved) {
          return;
        }
        console.error('[AllPartsInitialized] failed to resolve within time limit', {
          timeout,
          attemptState: props.state,
          partsLayout,
        });
      }, partInitWaitLimit);
    });
    sharedPromiseMap.set(activityId, { promise, resolve, reject });

    sharedInitMap.set(
      activityId,
      partsLayout.reduce((collect: Record<string, boolean>, part) => {
        collect[part.id] = false;
        return collect;
      }, {}),
    );

    console.log('INIT AD', { activityId, props, sharedAttemptStateMap, sharedInitMap });
    sharedAttemptStateMap.set(activityId, props.state);

    setInit(true);

    return () => {
      clearTimeout(timeout);
      sharedInitMap.delete(activityId);
      sharedPromiseMap.delete(activityId);
      sharedAttemptStateMap.delete(activityId);
      setInit(false);
    };
  }, []);

  const partInit = useCallback(
    async (partId: string) => {
      const currentAttemptState = sharedAttemptStateMap.get(activityId);
      const partsInitStatus = sharedInitMap.get(activityId);
      const partsInitDeferred = sharedPromiseMap.get(activityId);
      partsInitStatus[partId] = true;
      /* console.log(`%c INIT ${partId} CB`, 'background: blue;color:white;', {
        partsLayout,
        partsInitStatus,
      }); */
      if (partsLayout.every((part) => partsInitStatus[part.id] === true)) {
        if (props.onReady && !isReviewMode) {
          const readyResults: any = await props.onReady(currentAttemptState.attemptGuid);
          const { env, domain } = readyResults;
          if (env) {
            setScriptEnv(env);
          }
          if (domain) {
            setAdaptivityDomain(domain);
          }
          /* console.log('ACTIVITY READY RESULTS', readyResults); */
          partsInitDeferred.resolve({
            snapshot: readyResults.snapshot || {},
            context: {
              ...readyResults.context,
              host: props.mountPoint,
              domain: domain || adaptivityDomain,
            },
            env,
          });
        } else {
          // when calling onReady normally it would do all the init state and fill in from attempt state too
          const attemptStateMap = currentAttemptState.parts.reduce((collect: any, part: any) => {
            // build like we do a responseMap
            const { response } = part;
            if (response) {
              const responseElements = Object.keys(response).reduce((final: any, key) => {
                const responseElement = response[key];
                final[key] = responseElement;

                return final;
              }, {});
              collect = { ...collect, ...responseElements };
            }
            // TODO
            return collect;
          }, {});
          const testRes = evalAssignScript(attemptStateMap, scriptEnv);
          console.log('ACTIVITY READY RESULTS', { testRes, attemptStateMap });
          const snapshot = getLocalizedStateSnapshot([activityId], scriptEnv);
          // if for some reason this isn't defined, don't leave it hanging
          console.log('PARTS READY NO ONREADY HOST (REVIEW MODE)', {
            partId,
            scriptEnv,
            adaptivityDomain,
            props,
            snapshot,
            currentAttemptState,
          });
          const context = {
            snapshot,
            context: { mode: 'REVIEW', host: props.mountPoint },
            env: scriptEnv,
            domain: adaptivityDomain,
            initStateFacts: {},
            initStateBindToFacts: {},
          };
          partsInitDeferred.resolve(context);
          console.log('AD EMIT CONTEXT CHANGED', context);
          pusher.emit(NotificationType.CONTEXT_CHANGED, context);
        }
      }
      return partsInitDeferred.promise;
    },
    [partsLayout, adaptivityDomain],
  );

  const handlePartInit = async (payload: { id: string | number; responses: any[] }) => {
    console.log('onPartInit', payload);
    // a part should send initial state values
    if (payload.responses.length) {
      const saveResults = await handlePartSave(payload);
      console.log('onPartInit saveResults', payload.id, saveResults);
    }

    const { snapshot, context, env } = await partInit(payload.id.toString());
    // TODO: something with save result? check for errors?
    return { snapshot, context, env };
  };

  const handlePartReady = async (payload: { id: string | number }) => {
    /* console.log('onPartReady', { payload }); */
    return true;
  };

  const handlePartResize = async (payload: { id: string | number }) => {
    // no need to do anything for now.
    /*  console.log('handlePartResize called'); */
    return true;
  };

  const handleSetData = async (payload: any) => {
    const currentAttemptState = sharedAttemptStateMap.get(activityId);
    // part attempt guid should be located in currentAttemptState.parts matched to id
    const partAttempt = currentAttemptState.parts.find((p: any) => p.partId === payload.id);
    if (!partAttempt) {
      // throw err? if this happens we can't proceed...
      console.error(`part attempt guid for ${payload.id} not found!`);
      return;
    }
    if (props.onWriteUserState && !isReviewMode) {
      await props.onWriteUserState(
        currentAttemptState.attemptGuid,
        partAttempt?.attemptGuid,
        payload,
      );
    }
  };

  const handleGetData = async (payload: any) => {
    const currentAttemptState = sharedAttemptStateMap.get(activityId);
    // part attempt guid should be located in currentAttemptState.parts matched to id
    const partAttempt = currentAttemptState.parts.find((p: any) => p.partId === payload.id);
    if (!partAttempt) {
      // throw err? if this happens we can't proceed...
      console.error(`part attempt guid for ${payload.id} not found!`);
      return;
    }
    if (props.onReadUserState && !isReviewMode) {
      return await props.onReadUserState(
        currentAttemptState.attemptGuid,
        partAttempt?.attemptGuid,
        payload,
      );
    }
  };

  const handlePartSave = async ({ id, responses }: { id: string | number; responses: any[] }) => {
    /* console.log('onPartSave', { id, responses }); */
    if (!responses || !responses.length) {
      // TODO: throw? no reason to save something with no response
      console.warn(`[onPartSave: ${id}] called with no responses`);
      return;
    }
    const currentAttemptState = sharedAttemptStateMap.get(activityId);
    // part attempt guid should be located in currentAttemptState.parts matched to id
    const partAttempt = currentAttemptState.parts.find((p: any) => p.partId === id);
    if (!partAttempt) {
      // throw err? if this happens we can't proceed...
      console.error(`part attempt guid for ${id} not found!`, { currentAttemptState });
      return;
    }
    const response: ActivityTypes.StudentResponse = {
      input: responses.map((pr) => ({ ...pr, path: `${id}.${pr.key}` })),
    };
    if (props.onSavePart && !isReviewMode) {
      const result = await props.onSavePart(
        currentAttemptState.attemptGuid,
        partAttempt?.attemptGuid,
        response,
      );
      // BS: this is the result from the layout pushed down, need to push down to part here?
      return result;
    } else {
      console.warn('onSavePart not defined, not saving', { response, scriptEnv });
      // should write to the scriptEnv so that all parts can have the full snapshot?
      const statePrefix = `${activityId}|stage`;
      const responseMap = response.input.reduce(
        (result: { [x: string]: any }, item: { key: string; path: string }) => {
          result[item.key] = { ...item, path: `${statePrefix}.${item.path}` };
          return result;
        },
        {},
      );
      const evalResult = evalAssignScript(responseMap, scriptEnv);
      console.log(`[${id}] review mode save evalResult`, evalResult);
      return {
        type: 'success',
        snapshot: getLocalizedStateSnapshot([activityId], scriptEnv),
      };
    }
  };

  const handlePartSubmit = async ({ id, responses }: { id: string | number; responses: any[] }) => {
    /* console.log('onPartSubmit', { id, responses }); */
    const currentAttemptState = sharedAttemptStateMap.get(activityId);
    // part attempt guid should be located in currentAttemptState.parts matched to id
    const partAttempt = currentAttemptState.parts.find((p: any) => p.partId === id);
    if (!partAttempt) {
      // throw err? if this happens we can't proceed...
      console.error(`part attempt guid for ${id} not found!`);
      return;
    }
    const response: ActivityTypes.StudentResponse = {
      input: responses.map((pr) => ({ ...pr, path: `${id}.${pr.key}` })),
    };
    if (props.onSubmitPart && !isReviewMode) {
      const result = await props.onSubmitPart(
        currentAttemptState.attemptGuid,
        partAttempt?.attemptGuid,
        response,
      );
      // BS: this is the result from the layout pushed down, need to push down to part here?
      return result;
    } else {
      console.warn('onSubmitPart not defined, not submitting');
      return {
        type: 'success',
        snapshot: {},
      };
    }
  };

  return init ? (
    <NotificationContext.Provider value={pusher}>
      <>
        {isReviewMode ? (
          <style>
            {`
              style { display: none; }
              ${manifest.delivery.element} { min-height: 500px; display: block; position: relative; }
            `}
          </style>
        ) : null}
        <PartsLayoutRenderer
          parts={partsLayout}
          onPartInit={handlePartInit}
          onPartReady={handlePartReady}
          onPartSave={handlePartSave}
          onPartSubmit={handlePartSubmit}
          onPartResize={handlePartResize}
          onPartSetData={handleSetData}
          onPartGetData={handleGetData}
        />
      </>
    </NotificationContext.Provider>
  ) : null;
};

// Defines the web component, a simple wrapper over our React component above
export class AdaptiveDelivery extends DeliveryElement<AdaptiveModelSchema> {
  disconnectedCallback() {
    ReactDOM.unmountComponentAtNode(this.mountPoint);
    this.connected = false;
  }

  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}

// Register the web component:
window.customElements.define(manifest.delivery.element, AdaptiveDelivery);
