import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
} from '../DeliveryElement';
import { AdaptiveModelSchema } from './schema';
import * as ActivityTypes from '../types';
import * as Extrinsic from 'data/persistence/extrinsic';

const Adaptive = (props: DeliveryElementProps<AdaptiveModelSchema>) => {

  const [initialized, setInitialized] = useState(false);
  const [data, setData] = useState({});

  useEffect(() => {
    if (!initialized) {
      Extrinsic.read_global()
        .then(result => {
          setData(result);
        })
      setInitialized(true);
    }
  }, [initialized]);

  const scalar = () => {
    Extrinsic.upsert_global({ test: 'hello', again: 'no' })
      .then(r => Extrinsic.read_global())
      .then(r => setData(r));
  }

  const nested = () => {
    Extrinsic.upsert_global({ apple: { orange: 1 }, banana: ['no', 'yes'] })
      .then(r => Extrinsic.read_global())
      .then(r => setData(r));
  }

  return (
    <div>
      <h3>Adaptive Activity</h3>

      <h5>Global Data</h5>

      <pre>
        <code>
          {JSON.stringify(data, undefined, 2)}
        </code>
      </pre>

      <button onClick={scalar} className="btn btn-primary">Set Scalar</button>
      <button onClick={nested} className="btn btn-primary">Set Nested</button>

    </div>
  )
};

// Defines the web component, a simple wrapper over our React component above
export class AdaptiveDelivery extends DeliveryElement<AdaptiveModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}

// Register the web component:
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, AdaptiveDelivery);
