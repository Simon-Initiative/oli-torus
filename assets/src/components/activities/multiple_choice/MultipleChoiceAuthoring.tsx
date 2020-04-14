import React from 'react';
import ReactDOM from 'react-dom';

const MultipleChoice = (props: any) => {
  return (
    <div style={{ width: '100%', height: '100px', border: 'solid 1px gray' }}>
      <p>{props.model.stem}</p>
    </div>
  );
};

export class MultipleChoiceAuthoring extends HTMLElement {

  mountPoint: HTMLDivElement;

  constructor() {
    super();

    this.mountPoint = document.createElement('div');
  }

  props() {

    const token = this.getAttribute('token');
    const model = this.getAttribute('model');
    const state = this.getAttribute('state');

    return {
      token,
      model,
      state,
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
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);


