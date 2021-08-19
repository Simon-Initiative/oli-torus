import { NotificationContext } from 'apps/delivery/components/NotificationContext';
import EventEmitter from 'events';
import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import { AdaptiveModelSchema } from './schema';

const Adaptive = (props: AuthoringElementProps<AdaptiveModelSchema>) => {
  const [pusher, _setPusher] = useState(new EventEmitter());
  console.log('adaptive authoring', props);
  const parts = props.model?.content?.partsLayout || [];
  const [selectedPart, setSelectedPart] = useState('');

  const handlePartInit = async (payload: any) => {
    console.log('AUTHOR PART INIT', payload);
    return { snapshot: {} };
  };

  const handlePartClick = (payload: any) => {
    console.log('AUTHOR PART CLICK', payload);
    if (props.editMode) {
      setSelectedPart(payload.id);
    }
  };

  return parts && parts.length ? (
    <NotificationContext.Provider value={pusher}>
      <div>Parts Layout Render</div>
    </NotificationContext.Provider>
  ) : null;
};

export class AdaptiveAuthoring extends AuthoringElement<AdaptiveModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, AdaptiveAuthoring);
