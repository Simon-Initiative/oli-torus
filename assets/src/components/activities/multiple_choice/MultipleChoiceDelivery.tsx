import React from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { MultipleChoiceModelSchema } from './schema';


const MultipleChoice = (props: DeliveryElementProps<MultipleChoiceModelSchema>) => {
  return (
    <div style={{ width: '100%', height: '100px', border: 'solid 1px gray' }}>
      <h3>Multiple choice delivery.  A react component inside a web component</h3>
      <p>{props.model.stem}</p>
    </div>
  );
};

export class MultipleChoiceDelivery extends DeliveryElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(<MultipleChoice {...props} />, mountPoint);
  }
}

import * as ActivityTypes from '../types';
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, MultipleChoiceDelivery);
