import React from 'react';
import ReactDOM from 'react-dom';

const MultipleChoice = (props: any) => {
  return (
    <div style={{ width: '100%', height: '100px', border: 'solid 1px gray' }}>
      <h3>Multiple choice delivery.  A react component inside a web component</h3>
      <p>{props.model.stem}</p>
    </div>
  );
};


declare global {
  namespace JSX {
    interface IntrinsicElements {
      'oli-multiple-choice': any;
    }
  }
}

export class MultipleChoiceDelivery extends HTMLElement {

  mountPoint: HTMLDivElement;

  constructor() {
    super();
    this.mountPoint = document.createElement('div');
  }

  props() {
    const model = JSON.parse(this.getAttribute('model') as any);

    return {
      model,
    };
  }

  connectedCallback() {
    this.attachShadow({ mode: 'open' }).appendChild(this.mountPoint);
    ReactDOM.render(<MultipleChoice {...this.props()} />, this.mountPoint);
  }

  attributeChangedCallback(name: any, oldValue: any, newValue: any) {
    ReactDOM.render(<MultipleChoice {...this.props()} />, this.mountPoint);
  }
}

import * as ActivityTypes from '../types';
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, MultipleChoiceDelivery);
