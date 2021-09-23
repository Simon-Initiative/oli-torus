import ConfirmDelete from 'apps/authoring/components/Modal/DeleteConfirmationModal';
import { NotificationContext } from 'apps/delivery/components/NotificationContext';
import { AnyPartComponent, defaultCapabilities } from 'components/parts/types/parts';
import EventEmitter from 'events';
import React, { useCallback, useEffect, useState } from 'react';
import Draggable from 'react-draggable';
import { clone } from 'utils/common';
import PartComponent from '../common/PartComponent';

interface LayoutEditorProps {
  id: string;
  width: number;
  height: number;
  backgroundColor: string; // TODO: background: CSSProperties ??
  parts: AnyPartComponent[];
  selected: string;
  hostRef?: HTMLElement;
  onChange: (parts: AnyPartComponent[]) => void;
  onSelect: (partId: string) => void;
}

const defaultHandler = async () => {
  return {
    type: 'success',
    snapshot: {},
  };
};

const toolBarTopOffset = -38;

const LayoutEditor: React.FC<LayoutEditorProps> = (props) => {
  const [pusher, _setPusher] = useState(new EventEmitter().setMaxListeners(50));
  const [parts, setParts] = useState(props.parts);
  const [selectedPartId, setSelectedPartId] = useState(props.selected || '');
  const [configurePartId, setConfigurePartId] = useState('');
  const [selectedPart, setSelectedPart] = useState<any>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const [toolbarPosition, setToolbarPosition] = useState({ x: 0, y: 0 });

  // this effect keeps the local parts state in sync with the props
  useEffect(() => {
    setParts(props.parts);
  }, [props.parts]);

  // this effect keeps the local selected id in sync with the props
  useEffect(() => {
    if (props.selected !== selectedPartId) {
      setSelectedPartId(props.selected || '');
    }
  }, [props.selected]);

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
          // TODO: cache the instance data somewhere so we don't do this every time
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

  // this effect is to cover the case when the user is clicking "off" of a part to deselect it
  useEffect(() => {
    const handleHostClick = (e: any) => {
      const path = e.path;
      const pathIds =
        path?.map((node: HTMLElement) => node.getAttribute && node.getAttribute('id')) || [];
      // console.log('HOST CLICK', { pathIds, path, e });
      const isToolbarClick = pathIds.includes(`active-selection-toolbar-${props.id}`);
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

  const handlePartClick = useCallback(
    async (payload: any) => {
      // console.log('AUTHOR PART CLICK', { payload, props });
      if (selectedPartId === payload.id) {
        return;
      }
      setSelectedPartId(payload.id);
      props.onSelect(payload.id);
    },
    [selectedPartId],
  );

  const handlePartDrag = useCallback(
    async (payload: any) => {
      // console.log('AUTHOR PART DRAG', payload);
      if (payload.dragData.deltaX === 0 && payload.dragData.deltaY === 0) {
        return;
      }
      let transformStyle = ''; // 'transform: translate(0px, 0px);';
      const newPosition = { x: payload.dragData.x, y: payload.dragData.y };
      const partsClone = clone(parts);
      const part = partsClone.find((p: any) => p.id === payload.partId);
      if (part) {
        part.custom.x = newPosition.x;
        part.custom.y = newPosition.y;
        transformStyle = `transform: translate(${newPosition.x}px, ${newPosition.y}px);`;
        setToolbarPosition({ x: newPosition.x, y: newPosition.y + toolBarTopOffset });
      }

      // optimistically update parts
      setParts(partsClone);

      // update parent with changes
      props.onChange(partsClone);

      // need to reset the styling applied by react-draggable
      payload.dragData.node.setAttribute('style', transformStyle);
    },
    [parts],
  );

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
    const filteredParts = parts.filter((part) => part.id !== selectedPart.id);
    props.onChange(filteredParts);
    // optimistically update local state
    setParts(filteredParts);
    // just setting the part ID should trigger the selectedPart also to get reset
    setSelectedPartId('');
  }, [selectedPart, parts]);

  const DeleteComponentHandler = useCallback(() => {
    handlePartDelete();
    setShowConfirmDelete(false);
  }, [handlePartDelete]);

  const handlePartMoveForward = useCallback(async () => {
    console.log('AUTHOR PART MOVE FWD', { selectedPart });
    const partsClone = clone(parts);
    const part = partsClone.find((p: any) => p.id === selectedPart.id);
    part.custom.z = part.custom.z + 1;
    props.onChange(partsClone);
    // optimistically update local state
    setParts(partsClone);
  }, [selectedPart, parts]);

  const handlePartMoveBack = useCallback(async () => {
    console.log('AUTHOR PART MOVE BACK', { selectedPart });
    const partsClone = clone(parts);
    const part = partsClone.find((p: any) => p.id === selectedPart.id);
    part.custom.z = part.custom.z - 1;
    props.onChange(partsClone);
    // optimistically update local state
    setParts(partsClone);
  }, [selectedPart, parts]);

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
      const partsClone = clone(parts);
      const part = partsClone.find((p: any) => p.id === id);
      if (part) {
        part.custom = snapshot;

        // console.log('AUTHOR PART SAVE CONFIGURE', { id, snapshot, modelClone: clone(modelClone) });

        props.onChange(partsClone);
        setParts(partsClone);
      }
      setConfigurePartId('');
    },
    [parts],
  );

  const handlePortalBgClick = (e: any) => {
    // console.log('BG CLICK', { e });
    if (e.target.getAttribute('class') === 'part-config-container') {
      setConfigurePartId('');
    }
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

  return parts && parts.length ? (
    <NotificationContext.Provider value={pusher}>
      <div className="activity-content">
        <style>
          {`
          .activity-content {
            border: 1px solid #ccc;
            background-color: ${props.backgroundColor || '#fff'};
            width: ${props.width || 1000}px;
            height: ${props.height || 500}px;
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
          <div id={`part-portal-${props.id}`} className="part-config-container-inner"></div>
        </div>
        <div
          id={`active-selection-toolbar-${props.id}`}
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
            portal: `part-portal-${props.id}`,
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
              defaultPosition={{ x: part.custom.x || 0, y: part.custom.y || 0 }}
              disabled={disableDrag}
              onStart={() => {
                setIsDragging(true);
              }}
              onStop={(_, dragData) => {
                setIsDragging(false);
                handlePartDrag({ partId: part.id, dragData });
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

export default LayoutEditor;
