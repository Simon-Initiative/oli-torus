import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
} from '../DeliveryElement';
import { AdaptiveModelSchema } from './schema';

import { useGlobalState } from 'components/hooks/global';
import * as ActivityTypes from '../types';
import * as Extrinsic from 'data/persistence/extrinsic';

const Adaptive = (props: DeliveryElementProps<AdaptiveModelSchema>) => {

  const [active, setActive] = useState(true);
  const [handle, setHandle] = useState(null as any);

  const data = useGlobalState(props.userId, active);

  const scalar = () => {
    Extrinsic.upsert_global({ test: 'hello', again: 'no' });
  }

  const nested = () => {
    Extrinsic.upsert_global({ apple: { orange: 1 }, banana: ['no', 'yes'] });
  }

  const timer = () => {
    if (handle !== null) {
      clearInterval(handle);
      setHandle(null);
    } else {
      setHandle(setInterval(() => Extrinsic.upsert_global({ randomValue: Math.random() }), 500));
    }
  }

  const toggle = () => setActive(!active);

  return (
    <div>
      <h3>Adaptive Activity</h3>

      <h5>Global Data</h5>

      <pre>
        <code>
          {JSON.stringify(data, undefined, 2)}
        </code>
      </pre>


      <div className="form-check">
        <input className="form-check-input" type="checkbox" value="" checked={active} onChange={toggle} />
        <label className="form-check-label">
          Subscribe To Global State
        </label>
      </div>
      <button onClick={scalar} className="btn btn-primary btn-sm mr-2">Set Scalars</button>
      <button onClick={nested} className="btn btn-primary btn-sm mr-2">Set Nested</button>
      <button onClick={timer} className={`btn ${handle === null ? 'btn-primary' : 'btn-danger'} btn-sm`}>{handle === null ? 'Run Timer' : 'Stop Timer'}</button>

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
