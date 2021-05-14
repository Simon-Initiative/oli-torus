import React from 'react';
import ReactDOM from 'react-dom';
import PartsLayoutRenderer from '../../../apps/delivery/components/PartsLayoutRenderer';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import * as ActivityTypes from '../types';
import { AdaptiveModelSchema } from './schema';

const Adaptive = (props: DeliveryElementProps<AdaptiveModelSchema>) => {
  console.log('PROPS', { props });
  const {
    content: { custom: config, partsLayout },
  } = props.model;

  const parts = partsLayout || [];

  const handlePartInit = async (...args) => {
    console.log('onPartInit', args);
  };

  const handlePartReady = async (...args) => {
    console.log('onPartReady', args);
  };

  const handlePartSave = async (...args) => {
    console.log('onPartSave', args);
  };

  const handlePartSubmit = async (...args) => {
    console.log('onPartSubmit', args);
  };

  return (
    <PartsLayoutRenderer
      parts={parts}
      config={config}
      onPartInit={handlePartInit}
      onPartReady={handlePartReady}
      onPartSave={handlePartSave}
      onPartSubmit={handlePartSubmit}
    />
  );
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
