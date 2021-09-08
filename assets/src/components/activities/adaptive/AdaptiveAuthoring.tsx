import ConfirmDelete from 'apps/authoring/components/Modal/DeleteConfirmationModal';
import { NotificationContext } from 'apps/delivery/components/NotificationContext';
import chroma from 'chroma-js';
import EventEmitter from 'events';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import Draggable from 'react-draggable';
import { clone } from 'utils/common';
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
  const [selectedPartId, setSelectedPartId] = useState('');
  const [configurePartId, setConfigurePartId] = useState('');
  const [selectedPart, setSelectedPart] = useState<any>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);

  useEffect(() => {
    if (selectedPartId) {
      const part = parts.find((p) => p.id === selectedPartId);
      if (part) {
        setSelectedPart(part);
      }
    } else {
      setSelectedPart(null);
    }
    // any time selection changes we need to stop editing
    setConfigurePartId('');
  }, [selectedPartId, parts]);

  useEffect(() => {
    if (props.authoringContext) {
      setSelectedPartId(props.authoringContext.selectedPartId);
    }
  }, [props.authoringContext]);

  const handlePartInit = async (payload: any) => {
    console.log('AUTHOR PART INIT', payload);
    return { snapshot: {} };
  };

  const handlePartClick = async (payload: any) => {
    console.log('AUTHOR PART CLICK', { payload, props });
    if (!props.editMode) {
      return;
    }
    setSelectedPartId(payload.id);
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
    let paletteStyles = '';
    if (part.custom.palette) {
      const paletteStyleObj: CSSProperties = {};
      if (part.custom.palette.useHtmlProps) {
        paletteStyleObj.backgroundColor = part.custom.palette.backgroundColor;
        paletteStyleObj.borderColor = part.custom.palette.borderColor;
        paletteStyleObj.borderWidth = part.custom.palette.borderWidth;
        paletteStyleObj.borderStyle = part.custom.palette.borderStyle;
        paletteStyleObj.borderRadius = part.custom.palette.borderRadius;
      } else {
        paletteStyleObj.borderWidth = `${
          part.custom?.palette?.lineThickness ? part.custom?.palette?.lineThickness + 'px' : '1px'
        }`;
        paletteStyleObj.borderRadius = '10px';
        paletteStyleObj.borderStyle = 'solid';
        paletteStyleObj.borderColor = `rgba(${
          part.custom?.palette?.lineColor || part.custom?.palette?.lineColor === 0
            ? chroma(part.custom?.palette?.lineColor).rgb().join(',')
            : '255, 255, 255'
        },${part.custom?.palette?.lineAlpha})`;
        paletteStyleObj.backgroundColor = `rgba(${
          part.custom?.palette?.fillColor || part.custom?.palette?.fillColor === 0
            ? chroma(part.custom?.palette?.fillColor).rgb().join(',')
            : '255, 255, 255'
        },${part.custom?.palette?.fillAlpha})`;
      }
      paletteStyles = `
        background-color: ${paletteStyleObj.backgroundColor};
        border-color: ${paletteStyleObj.borderColor};
        border-width: ${paletteStyleObj.borderWidth}px;
        border-radius: ${paletteStyleObj.borderRadius}px;
        border-style: ${paletteStyleObj.borderStyle};
      `
    }

    return `#${part.id.replace(/:/g, '\\:')} {
      display: block;
      position: absolute;
      width: ${part.custom.width}px;
      top: ${part.custom.y}px;
      left: ${part.custom.x}px;
      z-index: ${part.custom.z};
      ${paletteStyles}
    }`;
  });

  const DeleteComponentHandler = () => {
    handlePartDelete();
    setShowConfirmDelete(false);
  };
  const handlePartEdit = useCallback(async () => {
    console.log('AUTHOR PART EDIT', { selectedPart });
  }, [selectedPart]);

  const handlePartConfigure = useCallback(async () => {
    console.log('AUTHOR PART CONFIGURE', { selectedPart, configurePartId });
    if (configurePartId === selectedPart.id) {
      setConfigurePartId('');
    } else {
      setConfigurePartId(selectedPart?.id);
    }
  }, [selectedPart, configurePartId]);

  const handlePartDelete = useCallback(async () => {
    console.log('AUTHOR PART DELETE', { selectedPart });
    const modelClone = clone(props.model);
    modelClone.content.partsLayout = parts.filter((part) => part.id !== selectedPart.id);
    modelClone.authoring.parts = modelClone.authoring.parts.filter(
      (part: any) => part.id !== selectedPart.id,
    );
    props.onEdit(modelClone);
  }, [selectedPart]);

  const handlePartMoveForward = useCallback(async () => {
    console.log('AUTHOR PART MOVE FWD', { selectedPart });
    const modelClone = clone(props.model);
    const part = modelClone.content.partsLayout.find((p: any) => p.id === selectedPart.id);
    part.custom.z = part.custom.z + 1;
    props.onEdit(modelClone);
  }, [selectedPart]);

  const handlePartMoveBack = useCallback(async () => {
    console.log('AUTHOR PART MOVE BACK', { selectedPart });
    const modelClone = clone(props.model);
    const part = modelClone.content.partsLayout.find((p: any) => p.id === selectedPart.id);
    part.custom.z = part.custom.z - 1;
    props.onEdit(modelClone);
  }, [selectedPart]);

  const handlePartCancelConfigure = useCallback(
    async ({ id }: { id: string }) => {
      console.log('AUTHOR PART CANCEL CONFIGURE', { id, configurePartId });
      if (!configurePartId) {
        // why is this necessary?
        setConfigurePartId('');
        return true;
      }
      if (id === configurePartId) {
        setConfigurePartId('');
        return true;
      }
      console.warn(`Part ${id} asked to cancel configure but ${configurePartId} is the one.`);
      return false;
    },
    [configurePartId],
  );

  const handlePartSaveConfigure = useCallback(
    async ({ id, snapshot }: { id: string; snapshot: any }) => {
      console.log('AUTHOR PART SAVE CONFIGURE', { id, snapshot });
      const modelClone = clone(props.model);
      const part = modelClone.content.partsLayout.find((p: any) => p.id === id);
      if (part) {
        part.custom = snapshot;
        props.onEdit(modelClone);
      }
      setConfigurePartId('');
    },
    [],
  );

  const handlePortalBgClick = (e: any) => {
    if (e.target.getAttribute('class') === 'part-config-container') {
      setConfigurePartId('');
    }
  };

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
          .active-selection-toolbar {
            position: absolute;
            z-index: 999;
          }
          .part-config-container {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.5);
            z-index: 9999;
          }
          .part-config-container-inner > :first-child {
            position: absolute;
            top: 15%;
            left: 25%;
            background-color: #fff;
          }
          ${partStyles.join('\n')}
        `}
        </style>
        <div
          className="part-config-container"
          style={{ display: configurePartId.trim() ? 'block' : 'none' }}
          onClick={handlePortalBgClick}
        >
          <div id={`part-portal-${props.model.id}`} className="part-config-container-inner"></div>
        </div>
        <div
          className="active-selection-toolbar"
          style={{
            display: selectedPart && !isDragging ? 'block' : 'none',
            top: (selectedPart?.custom.y || 0) - 36,
            left: (selectedPart?.custom.x || 0) + 4,
          }}
        >
          <button title="Edit" onClick={handlePartConfigure}>
            <i className="las la-edit"></i>
          </button>
          {/* <button title="Configure" onClick={handlePartConfigure}>
            <i className="las la-cog"></i>
          </button> */}
          <button title="Move Forward" onClick={handlePartMoveForward}>
            <i className="las la-plus"></i>
          </button>
          <button title="Move Back" onClick={handlePartMoveBack}>
            <i className="las la-minus"></i>
          </button>
          <button title="Delete" onClick={() => setShowConfirmDelete(true)}>
            <i className="las la-trash"></i>
          </button>
          <ConfirmDelete
            show={showConfirmDelete}
            elementType="Component"
            elementName={selectedPart?.id}
            deleteHandler={DeleteComponentHandler}
            cancelHandler={() => {
              setShowConfirmDelete(false);
            }}
          />
        </div>
        {parts.map((part) => {
          const partProps = {
            id: part.id,
            type: part.type,
            model: part.custom,
            state: {},
            configureMode: part.id === configurePartId,
            editMode: true,
            portal: `part-portal-${props.model.id}`,
            onInit: defaultHandler,
            onReady: defaultHandler,
            onSave: defaultHandler,
            onSubmit: defaultHandler,
          };
          return (
            <Draggable
              key={part.id}
              grid={[5, 5]}
              disabled={selectedPartId !== part.id || part.id === configurePartId}
              onStart={() => {
                setIsDragging(true);
              }}
              onStop={(_, { x, y, node }) => {
                setIsDragging(false);
                handlePartDrag({ id: part.id, x, y, node });
              }}
            >
              <PartComponent
                {...partProps}
                className={selectedPartId === part.id ? 'selected' : ''}
                onClick={() => handlePartClick({ id: part.id })}
                onSaveConfigure={handlePartSaveConfigure}
                onCancelConfigure={handlePartCancelConfigure}
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
