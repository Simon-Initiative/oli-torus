import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { AdaptiveModelSchema } from './schema';

import { useGlobalState } from 'components/hooks/global';
import * as ActivityTypes from '../types';
import * as Extrinsic from 'data/persistence/extrinsic';

const randomInt = () => Math.floor(Math.random() * 100);

const Adaptive = (props: DeliveryElementProps<AdaptiveModelSchema>) => {
  const [active, setActive] = useState(true);
  const [handle, setHandle] = useState(null as any);
  const [local, setLocal] = useState(props.state.parts[0].response);

  const data = useGlobalState(props.userId, active);

  const scalar = () => {
    Extrinsic.upsertGlobal({ scalar: randomInt() });
  };

  const nested = () => {
    Extrinsic.upsertGlobal({ nested: { multiple: { levels: randomInt() } } });
  };

  const save = () => {
    const local = randomInt();
    props
      .onSaveActivity(props.state.attemptGuid, [
        { attemptGuid: props.state.parts[0].attemptGuid, response: { input: { local } } },
      ])
      .then((result: any) => {
        setLocal({ input: { local } });
      });
  };

  const timer = () => {
    if (handle !== null) {
      clearInterval(handle);
      setHandle(null);
    } else {
      setHandle(setInterval(() => Extrinsic.upsertGlobal({ randomValue: randomInt() }), 100));
    }
  };

  const toggle = () => setActive(!active);

  return (
    <div style={{ border: '3px dashed lightgray', padding: '10px', margin: '10px' }}>
      <h3>Adaptive Activity</h3>

      <h5>Global State</h5>

      <div className="m-3">
        <pre>
          <code>{JSON.stringify(data, undefined, 2)}</code>
        </pre>

        <div className="form-check">
          <input
            className="form-check-input"
            type="checkbox"
            value=""
            checked={active}
            onChange={toggle}
          />
          <label className="form-check-label">Subscribe To Global State</label>
        </div>
        <button onClick={scalar} className="btn btn-primary btn-sm mr-2">
          Set Scalars
        </button>
        <button onClick={nested} className="btn btn-primary btn-sm mr-2">
          Set Nested
        </button>
        <button
          onClick={timer}
          className={`btn ${handle === null ? 'btn-primary' : 'btn-danger'} btn-sm`}
        >
          {handle === null ? 'Run Timer' : 'Stop Timer'}
        </button>
      </div>

      <h5>Attempt State</h5>
      <div className="m-3">
        <pre>
          <code>{JSON.stringify(local, undefined, 2)}</code>
        </pre>

        <button onClick={save} className="btn btn-primary btn-sm mr-2">
          Update State
        </button>
      </div>
    </div>
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
