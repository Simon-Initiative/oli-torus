import { NotificationContext } from 'apps/delivery/components/NotificationContext';
import EventEmitter from 'events';
import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import PartComponent from './components/common/PartComponent';
import { AdaptiveModelSchema } from './schema';
import Draggable from 'react-draggable';

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
    console.log('AUTHOR PART CLICK', payload, props);
    //if (props.editMode) {
    setSelectedPart(payload.id);
    //}
  };

  const partStyles = parts.map((part) => {
    return `#${part.id.replace(/:/g, '\\:')} {
      display: block;
      position: absolute;
      width: ${part.custom.width}px;
      left: ${part.custom.x}px;
      top: ${part.custom.y}px;
      z-index: ${part.custom.z};
    }`;
  });

  const tempWhitelist = ['janus-image'];

  return parts && parts.length ? (
    <NotificationContext.Provider value={pusher}>
      <style>
        {`
          .react-draggable {
            position: absolute;
            cursor: move;
          }
          .react-draggable.selected::before{
            content: "";
            width: calc(100% + 10px);
            height: calc(100% + 10px);
            position: absolute;
            top: -5px;
            left: -5px;
            border: 2px #00ff00 dashed;
            z-index: -1;
          }
          ${partStyles.join('\n')}
        `}
      </style>
      {parts.map((part) => {
        const partType = tempWhitelist.includes(part.type) ? part.type : `${part.type}-foo`;
        const partProps = {
          id: part.id,
          type: partType,
          model: part.custom,
          state: {},
          editMode: true,
          onInit: async () => null,
          onReady: async () => null,
          onSave: async () => null,
          onSubmit: async () => null,
        };
        return (
          <Draggable key={part.id} grid={[5, 5]} disabled={selectedPart !== part.id}>
            <PartComponent
              {...partProps}
              className={selectedPart === part.id ? 'selected' : ''}
              onClick={() => handlePartClick({ id: part.id })}
            />
          </Draggable>
        );
      })}
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
