import ConfirmDelete from 'apps/authoring/components/Modal/DeleteConfirmationModal';
import { NotificationContext } from 'apps/delivery/components/NotificationContext';
import { defaultCapabilities } from 'components/parts/types/parts';
import EventEmitter from 'events';
import React, { useCallback, useEffect, useState } from 'react';
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

const toolBarTopOffset = -38;

const Adaptive = (
  props: AuthoringElementProps<AdaptiveModelSchema> & { hostRef?: HTMLElement },
) => {
  const [pusher, _setPusher] = useState(new EventEmitter().setMaxListeners(50));
  const [selectedPartId, setSelectedPartId] = useState('');
  const [configurePartId, setConfigurePartId] = useState('');
  const [selectedPart, setSelectedPart] = useState<any>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);

  const [toolbarPosition, setToolbarPosition] = useState({ x: 0, y: 0 });

  const [parts, setParts] = useState<any[]>(props.model?.content?.partsLayout || []);

  // this effect is to cover the case when the user is clicking "off" of a part to deselect it
  useEffect(() => {
    const handleHostClick = (e: any) => {
      const path = e.path;
      const pathIds =
        path?.map((node: HTMLElement) => node.getAttribute && node.getAttribute('id')) || [];
      // console.log('HOST CLICK', { pathIds, path, e });
      const isToolbarClick = pathIds.includes(`active-selection-toolbar-${props.model.id}`);
      const isInConfigMode = configurePartId !== '';
      // TODO: ability to click things underneath other things using path and selection
      if (!isInConfigMode && !isToolbarClick && !parts.find((p) => pathIds.includes(p.id))) {
        setSelectedPartId('');
      }
    };
    if (props.hostRef) {
      props.hostRef.addEventListener('click', handleHostClick);
    }
    return () => {
      if (props.hostRef) {
        props.hostRef.removeEventListener('click', handleHostClick);
      }
    };
  }, [props, parts, configurePartId]);

  // this effect keeps the local parts state in sync with the props
  useEffect(() => {
    setParts(props.model?.content?.partsLayout || []);
  }, [props.model]);

  // this effect keeps the toolbar positioned next to the selected part
  useEffect(() => {
    const x = selectedPart?.custom.x || 0;
    const y = (selectedPart?.custom.y || 0) + toolBarTopOffset;
    if (toolbarPosition.x !== x && toolbarPosition.y !== y) {
      setToolbarPosition({ x, y });
    }
  }, [selectedPart]);

  // this keeps a reference to the actual part data of the selected part id in local state
  useEffect(() => {
    if (selectedPartId) {
      const part = parts.find((p) => p.id === selectedPartId);
      if (part) {
        let capabilities = { ...defaultCapabilities };
        // attempt to get an instance of the part class
        const PartClass = customElements.get(part.type);
        if (PartClass) {
          const instance = new PartClass() as any; // TODO: extend HTMLElement?
          if (instance.getCapabilities) {
            capabilities = { ...capabilities, ...instance.getCapabilities() };
          }
        }
        setSelectedPart({ ...part, capabilities });
      }
    } else {
      setSelectedPart(null);
    }
    // any time selection changes we need to stop editing
    setConfigurePartId('');
    console.log('PART SELECTION CHANGED', { selectedPartId, selectedPart });
  }, [selectedPartId, parts]);

  // this effect sets the selection from the outside based on authoring context
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
    // console.log('AUTHOR PART CLICK', { payload, props });
    if (!props.editMode || selectedPartId === payload.id) {
      return;
    }
    setSelectedPartId(payload.id);
    if (props.onCustomEvent) {
      const result = await props.onCustomEvent('selectPart', payload);
      console.log('got result from onSelect', result);
    }
  };

  const handlePartDrag = async (payload: any) => {
    // console.log('AUTHOR PART DRAG', payload);
    if (payload.dragData.deltaX === 0 && payload.dragData.deltaY === 0) {
      return;
    }
    let transformStyle = ''; // 'transform: translate(0px, 0px);';
    if (props.onCustomEvent) {
      const result = await props.onCustomEvent('dragPart', payload);
      if (result) {
        transformStyle = `transform: translate(${result.x}px, ${result.y}px);`;
        setToolbarPosition({ x: result.x, y: result.y + toolBarTopOffset });
      }
    }

    // optimistically update part location and sync with draggable

    // need to reset the styling applied by react-draggable
    payload.dragData.node.setAttribute('style', transformStyle);
  };

  const partStyles = parts.map((part) => {
    return `#${part.id.replace(/:/g, '\\:')} {
      display: block;
      position: absolute;
      width: ${part.custom.width}px;
      top: 0px;
      left: 0px;
      transform: translate(${part.custom.x || 0}px, ${part.custom.y || 0}px);
      z-index: ${part.custom.z};
    }`;
  });

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
    // console.log('AUTHOR PART DELETE', { selectedPart });
    const modelClone = clone(props.model);
    modelClone.content.partsLayout = parts.filter((part) => part.id !== selectedPart.id);
    modelClone.authoring.parts = modelClone.authoring.parts.filter(
      (part: any) => part.id !== selectedPart.id,
    );
    props.onEdit(modelClone);
    // optimistically remove part from model
    setParts(modelClone.content.partsLayout);
    // just setting the part ID should trigger the selectedPart also to get reset
    setSelectedPartId('');
  }, [selectedPart, props.model]);

  const DeleteComponentHandler = useCallback(() => {
    handlePartDelete();
    setShowConfirmDelete(false);
  }, [handlePartDelete]);

  const handlePartMoveForward = useCallback(async () => {
    console.log('AUTHOR PART MOVE FWD', { selectedPart });
    const modelClone = clone(props.model);
    const part = modelClone.content.partsLayout.find((p: any) => p.id === selectedPart.id);
    part.custom.z = part.custom.z + 1;
    props.onEdit(modelClone);
  }, [selectedPart, props.model]);

  const handlePartMoveBack = useCallback(async () => {
    console.log('AUTHOR PART MOVE BACK', { selectedPart });
    const modelClone = clone(props.model);
    const part = modelClone.content.partsLayout.find((p: any) => p.id === selectedPart.id);
    part.custom.z = part.custom.z - 1;
    props.onEdit(modelClone);
  }, [selectedPart, props.model]);

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
      const modelClone = clone(props.model);
      const part = modelClone.content.partsLayout.find((p: any) => p.id === id);
      if (part) {
        part.custom = snapshot;

        // console.log('AUTHOR PART SAVE CONFIGURE', { id, snapshot, modelClone: clone(modelClone) });

        props.onEdit(modelClone);
      }
      setConfigurePartId('');
    },
    [props.model],
  );

  const handlePortalBgClick = (e: any) => {
    // console.log('BG CLICK', { e });
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
            top: 15px;
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
          id={`active-selection-toolbar-${props.model.id}`}
          className="active-selection-toolbar"
          style={{
            display: selectedPart && !isDragging ? 'block' : 'none',
            top: toolbarPosition.y,
            left: toolbarPosition.x,
          }}
        >
          {selectedPart && selectedPart.capabilities.configure && (
            <button title="Edit" onClick={handlePartConfigure}>
              <i className="las la-edit"></i>
            </button>
          )}
          {/* <button title="Configure" onClick={handlePartConfigure}>
            <i className="las la-cog"></i>
          </button> */}
          {selectedPart && selectedPart.capabilities.move && (
            <button title="Move Forward" onClick={handlePartMoveForward}>
              <i className="las la-plus"></i>
            </button>
          )}
          {selectedPart && selectedPart.capabilities.move && (
            <button title="Move Back" onClick={handlePartMoveBack}>
              <i className="las la-minus"></i>
            </button>
          )}
          {selectedPart && selectedPart.capabilities.delete && (
            <button title="Delete" onClick={() => setShowConfirmDelete(true)}>
              <i className="las la-trash"></i>
            </button>
          )}
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
            onResize: defaultHandler,
          };
          const disableDrag =
            selectedPartId !== part.id ||
            part.id === configurePartId ||
            (selectedPart && !selectedPart.capabilities.move);
          return (
            <Draggable
              key={part.id}
              grid={[5, 5]}
              defaultPosition={{ x: part.custom.x, y: part.custom.y }}
              disabled={disableDrag}
              onStart={() => {
                setIsDragging(true);
              }}
              onStop={(_, dragData) => {
                setIsDragging(false);
                handlePartDrag({ activityId: props.model.id, partId: part.id, dragData });
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
  props() {
    const superProps = super.props();
    return {
      ...superProps,
      hostRef: this,
    };
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, AdaptiveAuthoring);
