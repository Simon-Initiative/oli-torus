import React from 'react';
import ReactDOM from 'react-dom';
import {
  ActivityBankSelectionPreview,
  ActivityBankSelectionPreviewPayload,
} from './ActivityBankSelectionPreview';

class ActivityBankSelectionPreviewElement extends HTMLElement {
  mountPoint: HTMLDivElement;
  connected: boolean;

  constructor() {
    super();

    this.mountPoint = document.createElement('div');
    this.connected = false;
  }

  props() {
    const payload = JSON.parse(
      this.getAttribute('payload') || '{}',
    ) as ActivityBankSelectionPreviewPayload;

    return { payload };
  }

  render() {
    ReactDOM.render(<ActivityBankSelectionPreview {...this.props()} />, this.mountPoint);
  }

  connectedCallback() {
    this.appendChild(this.mountPoint);
    this.render();
    this.connected = true;
  }

  attributeChangedCallback() {
    if (this.connected) {
      this.render();
    }
  }

  static observedAttributes = ['payload'];
}

if (!window.customElements.get('oli-activity-bank-selection-preview')) {
  window.customElements.define(
    'oli-activity-bank-selection-preview',
    ActivityBankSelectionPreviewElement,
  );
}
