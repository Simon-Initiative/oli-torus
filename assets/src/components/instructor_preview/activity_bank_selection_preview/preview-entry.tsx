import React from 'react';
import ReactDOM from 'react-dom';
import {
  ActivityBankSelectionPreview,
  ActivityBankSelectionPreviewPayload,
} from './ActivityBankSelectionPreview';

const isNumber = (value: unknown): value is number => typeof value === 'number';
const isString = (value: unknown): value is string => typeof value === 'string';

const isValidPayload = (value: unknown): value is ActivityBankSelectionPreviewPayload => {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Record<string, unknown>;
  const target =
    candidate.customizationTarget && typeof candidate.customizationTarget === 'object'
      ? (candidate.customizationTarget as Record<string, unknown>)
      : null;

  return (
    isString(candidate.id) &&
    isString(candidate.title) &&
    isNumber(candidate.selectedCount) &&
    isNumber(candidate.availableCount) &&
    isNumber(candidate.pointsPerActivity) &&
    !!target &&
    target.kind === 'bank_selection' &&
    isNumber(target.pageResourceId) &&
    isString(target.selectionId)
  );
};

class ActivityBankSelectionPreviewElement extends HTMLElement {
  mountPoint: HTMLDivElement;
  connected: boolean;

  constructor() {
    super();

    this.mountPoint = document.createElement('div');
    this.connected = false;
  }

  props() {
    const encodedPayload = this.getAttribute('payload');

    if (!encodedPayload) {
      return null;
    }

    try {
      const payload = JSON.parse(encodedPayload) as unknown;

      if (!isValidPayload(payload)) {
        return null;
      }

      return { payload };
    } catch {
      return null;
    }
  }

  render() {
    const props = this.props();

    if (!props) {
      ReactDOM.unmountComponentAtNode(this.mountPoint);
      return;
    }

    ReactDOM.render(<ActivityBankSelectionPreview {...props} />, this.mountPoint);
  }

  connectedCallback() {
    if (!this.contains(this.mountPoint)) {
      this.appendChild(this.mountPoint);
    }

    this.render();
    this.connected = true;
  }

  disconnectedCallback() {
    ReactDOM.unmountComponentAtNode(this.mountPoint);
    this.connected = false;
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
