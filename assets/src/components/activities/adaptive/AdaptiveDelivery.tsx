import { EventEmitter } from 'events';
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import {
  NotificationContext,
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import PartsLayoutRenderer from '../../../apps/delivery/components/PartsLayoutRenderer';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import * as ActivityTypes from '../types';
import { AdaptiveModelSchema } from './schema';

const sharedInitMap = new Map();
const sharedPromiseMap = new Map();

const Adaptive = (props: DeliveryElementProps<AdaptiveModelSchema>) => {
  const {
    content: { custom: config, partsLayout },
  } = props.model;

  const [pusher, setPusher] = useState(new EventEmitter());

  const attemptState = props.state;

  const parts = partsLayout || [];

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
      const handler = (e) => {
        console.log(`${notificationType.toString()} notification handled [AD]`, e);
        // here we need to check when the context changes (current activityId) if we are a layer
        // (should only be possible as a layer, because other activities should be unloaded and loaded fresh)
        // layers need to re-init the parts, BUT not re-render them (this is mostly for capi sims)
        // because of the init promise is already resolved with the state snapshot it had the first time
        // the layer rendered, the parts can't simply call init again or they will not get the latest changes
        // still we just currently push notifications straight through, CONTEXT_CHANGED should have the latest snapshot

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
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  useEffect(() => {
    let timeout: NodeJS.Timeout;
    let resolve;
    let reject;
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
          attemptState,
          parts,
        });
      }, 2000);
    });
    sharedPromiseMap.set(props.model.id, { promise, resolve, reject });

    sharedInitMap.set(
      props.model.id,
      parts.reduce((collect: Record<string, boolean>, part) => {
        collect[part.id] = false;
        return collect;
      }, {}),
    );

    setInit(true);

    return () => {
      clearTimeout(timeout);
      sharedInitMap.delete(props.model.id);
      sharedPromiseMap.delete(props.model.id);
      setInit(false);
    };
  }, []);

  const partInit = useCallback(
    async (partId: string) => {
      const partsInitStatus = sharedInitMap.get(props.model.id);
      const partsInitDeferred = sharedPromiseMap.get(props.model.id);
      partsInitStatus[partId] = true;
      /* console.log(`%c INIT ${partId} CB`, 'background: blue;color:white;', {
        parts,
        partsInitStatus,
      }); */
      if (parts.every((part) => partsInitStatus[part.id] === true)) {
        if (props.onReady) {
          const readyResults: any = await props.onReady(attemptState.attemptGuid);
          /* console.log('ACTIVITY READY RESULTS', readyResults); */
          partsInitDeferred.resolve({ snapshot: readyResults.snapshot || {} });
        } else {
          // if for some reason this isn't defined, don't leave it hanging
          partsInitDeferred.resolve({ snapshot: {} });
        }
      }
      return partsInitDeferred.promise;
    },
    [parts],
  );

  const handlePartInit = async (payload: { id: string | number; responses: any[] }) => {
    /* console.log('onPartInit', payload); */
    // a part should send initial state values
    if (payload.responses.length) {
      const saveResults = await handlePartSave(payload);
    }

    const { snapshot } = await partInit(payload.id.toString());
    // TODO: something with save result? check for errors?
    return { snapshot };
  };

  const handlePartReady = async (payload: { id: string | number }) => {
    /* console.log('onPartReady', { payload }); */
    return true;
  };

  const handlePartSave = async ({ id, responses }: { id: string | number; responses: any[] }) => {
    /* console.log('onPartSave', { id, responses }); */
    if (!responses || !responses.length) {
      // TODO: throw? no reason to save something with no response
      return;
    }
    // part attempt guid should be located in attemptState.parts matched to id (i think)
    const partAttempt = attemptState.parts.find((p) => p.partId === id);
    if (!partAttempt) {
      // throw err? if this happens we can't proceed...
      console.error(`part attempt guid for ${id} not found!`);
      return;
    }
    const response: ActivityTypes.StudentResponse = {
      input: responses.map((pr) => ({ ...pr, path: `${id}.${pr.key}` })),
    };
    const result = await props.onSavePart(
      attemptState.attemptGuid,
      partAttempt?.attemptGuid,
      response,
    );
    // BS: this is the result from the layout pushed down, need to push down to part here?
    return result;
  };

  const handlePartSubmit = async ({ id, responses }: { id: string | number; responses: any[] }) => {
    /* console.log('onPartSubmit', { id, responses }); */
    // part attempt guid should be located in attemptState.parts matched to id (i think)
    const partAttempt = attemptState.parts.find((p) => p.partId === id);
    if (!partAttempt) {
      // throw err? if this happens we can't proceed...
      console.error(`part attempt guid for ${id} not found!`);
      return;
    }
    const response: ActivityTypes.StudentResponse = {
      input: responses.map((pr) => ({ ...pr, path: `${id}.${pr.key}` })),
    };
    const result = await props.onSubmitPart(
      attemptState.attemptGuid,
      partAttempt?.attemptGuid,
      response,
    );
    // BS: this is the result from the layout pushed down, need to push down to part here?
    return result;
  };

  return init ? (
    <NotificationContext.Provider value={pusher}>
      <PartsLayoutRenderer
        parts={parts}
        onPartInit={handlePartInit}
        onPartReady={handlePartReady}
        onPartSave={handlePartSave}
        onPartSubmit={handlePartSubmit}
      />
    </NotificationContext.Provider>
  ) : null;
};

// Defines the web component, a simple wrapper over our React component above
export class AdaptiveDelivery extends DeliveryElement<AdaptiveModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, AdaptiveDelivery);
