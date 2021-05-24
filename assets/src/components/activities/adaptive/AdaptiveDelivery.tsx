import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import PartsLayoutRenderer from '../../../apps/delivery/components/PartsLayoutRenderer';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import * as ActivityTypes from '../types';
import { AdaptiveModelSchema } from './schema';

const sharedInitMap = new Map();

const Adaptive = (props: DeliveryElementProps<AdaptiveModelSchema>) => {
  console.log('ADAPTIVE ACTIVITY RENDER: ', { props });
  const {
    content: { custom: config, partsLayout },
  } = props.model;

  const attemptState = props.state;

  const parts = partsLayout || [];

  const [allPartsInitialized, setAllPartsInitialized] = useState<any>(null);

  useEffect(() => {
    let resolve;
    let reject;
    const promise = new Promise((res, rej) => {
      resolve = res;
      reject = rej;
    });
    setAllPartsInitialized({ promise, resolve, reject });
    sharedInitMap.set(
      props.model.id,
      parts.reduce((collect: Record<string, boolean>, part) => {
        collect[part.id] = false;
        return collect;
      }, {}),
    );
    // TODO: timeout auto promise resolve/reject?
    return () => {
      sharedInitMap.delete(props.model.id);
    };
  }, []);

  const partInit = useCallback(
    async (partId: string) => {
      console.log(`%c INIT ${partId} CB`, 'background: blue;color:white;');
      const partsInitStatus = sharedInitMap.get(props.model.id);
      partsInitStatus[partId] = true;
      if (parts.every((part) => partsInitStatus[part.id] === true)) {
        if (props.onReady) {
          const readyResults: any = await props.onReady(attemptState.attemptGuid);
          console.log('ACTIVITY READY RESULTS', readyResults);
          allPartsInitialized.resolve({ snapshot: readyResults.snapshot || {} });
        } else {
          // if for some reason this isn't defined, don't leave it hanging
          allPartsInitialized.resolve({ snapshot: {} });
        }
      }
      return allPartsInitialized.promise;
    },
    [allPartsInitialized, parts],
  );

  const handlePartInit = async (payload: { id: string | number; responses: any[] }) => {
    console.log('onPartInit', payload);
    // a part should send initial state values
    const saveResults = await handlePartSave(payload);
    const { snapshot } = await partInit(payload.id.toString());
    // TODO: something with save result? check for errors?
    return { snapshot };
  };

  const handlePartReady = async (payload: { id: string | number }) => {
    console.log('onPartReady', { payload });
    return true;
  };

  const handlePartSave = async ({ id, responses }: { id: string | number; responses: any[] }) => {
    console.log('onPartSave', { id, responses });
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
    console.log('onPartSubmit', { id, responses });
    // part attempt guid should be located in attemptState.parts matched to id (i think)
    const partAttempt = attemptState.parts.find((p) => p.partId === id);
    if (!partAttempt) {
      // throw err? if this happens we can't proceed...
      console.error(`part attempt guid for ${id} not found!`);
      return;
    }
    const response: ActivityTypes.StudentResponse = {
      input: responses,
    };
    const result = await props.onSubmitPart(
      attemptState.attemptGuid,
      partAttempt?.attemptGuid,
      response,
    );
    // BS: this is the result from the layout pushed down, need to push down to part here?
    return result;
  };

  return allPartsInitialized !== null ? (
    <PartsLayoutRenderer
      parts={parts}
      onPartInit={handlePartInit}
      onPartReady={handlePartReady}
      onPartSave={handlePartSave}
      onPartSubmit={handlePartSubmit}
    />
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
