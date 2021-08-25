import { NotificationContext } from 'apps/delivery/components/NotificationContext';
import EventEmitter from 'events';
import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import Draggable from 'react-draggable';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import PartComponent from './components/common/PartComponent';
import { AdaptiveModelSchema } from './schema';

const defaultHandler = async () => {
  return {
    type: 'success',
    snapshot: {},
  };
};

const Adaptive = (props: AuthoringElementProps<AdaptiveModelSchema>) => {
  const [pusher, _setPusher] = useState(new EventEmitter());
  console.log('adaptive authoring', props);
  const parts = props.model?.content?.partsLayout || [];
  const [selectedPart, setSelectedPart] = useState('');

  const handlePartInit = async (payload: any) => {
    console.log('AUTHOR PART INIT', payload);
    return { snapshot: {} };
  };

  const handlePartClick = async (payload: any) => {
    console.log('AUTHOR PART CLICK', payload, props);
    //if (props.editMode) {
    setSelectedPart(payload.id);
    //}
    if (props.onCustomEvent) {
      const result = await props.onCustomEvent('selectPart', payload);
      console.log('got result from onSelect', result);
    }
  };

  const handlePartDrag = async (payload: any) => {
    console.log('AUTHOR PART DRAG', payload);
    // TODO: optimistically update part location and sync with draggable?
    if (props.onCustomEvent) {
      const result = await props.onCustomEvent('dragPart', payload);
      console.log('got result from onDrag', result);
    }
    // need to reset the styling applied by react-draggable
    payload.node.setAttribute('style', '');
  };

  const partStyles = parts.map((part) => {
    return `#${part.id.replace(/:/g, '\\:')} {
      display: block;
      position: absolute;
      width: ${part.custom.width}px;
      top: ${part.custom.y}px;
      left: ${part.custom.x}px;
      z-index: ${part.custom.z};
    }`;
  });

  return parts && parts.length ? (
    <NotificationContext.Provider value={pusher}>
      <div className="activity-content">
        <style>
          {`
          .activity-content {
            border: 1px solid #ccc;
            background-color: ${props.model.content?.custom?.palette.backgroundColor || '#fff'};
            width: ${props.model.content?.custom?.width || 1000}px;
            height: ${props.model.content?.custom?.height || 500}px;
          }
          .react-draggable {
            position: absolute;
            cursor: pointer;
          }
          .react-draggable.selected {
            cursor: move;
          }
          .react-draggable:hover::before{
            content: "";
            width: calc(100% + 10px);
            height: calc(100% + 10px);
            position: absolute;
            top: -5px;
            left: -5px;
            border: 1px #ccc solid;
            z-index: -1;
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
          const partProps = {
            id: part.id,
            type: part.type,
            model: part.custom,
            state: {},
            editMode: true,
            onInit: defaultHandler,
            onReady: defaultHandler,
            onSave: defaultHandler,
            onSubmit: defaultHandler,
          };
          return (
            <Draggable
              key={part.id}
              grid={[5, 5]}
              disabled={selectedPart !== part.id}
              onDrag={(e, data) => {
                console.log('DRAGGING', data);
              }}
              onStop={(_, { x, y, node }) => {
                handlePartDrag({ id: part.id, x, y, node });
              }}
            >
              <PartComponent
                {...partProps}
                className={selectedPart === part.id ? 'selected' : ''}
                onClick={() => handlePartClick({ id: part.id })}
              />
            </Draggable>
          );
        })}
      </div>
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
