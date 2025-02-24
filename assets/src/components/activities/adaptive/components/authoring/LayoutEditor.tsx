import React, { useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import EventEmitter from 'events';
import {
  AnyPartComponent,
  AnyPartModel,
  PartCapabilities,
  defaultCapabilities,
} from 'components/parts/types/parts';
import ConfirmDelete from 'apps/authoring/components/Modal/DeleteConfirmationModal';
import {
  NotificationContext,
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone } from 'utils/common';
import { contexts } from '../../../../../types/applicationContext';
import PartComponent from '../common/PartComponent';
import { ResizeContainer } from './ResizeContainer';

interface LayoutEditorProps {
  id: string;
  width: number;
  height: number;
  backgroundColor: string; // TODO: background: CSSProperties ??
  parts: AnyPartComponent[];
  selected: string;
  hostRef?: HTMLElement;
  configurePortalId?: string;
  onChange: (parts: AnyPartComponent[], selectedPartId?: string, isDeleted?: boolean) => void;
  onSelect: (partId: string) => void;
  onCopyPart?: (part: any) => Promise<any>;
  onConfigurePart?: (part: any, context: any) => Promise<any>;
  onCancelConfigurePart?: (partId: string) => Promise<any>;
}

const defaultHandler = async () => {
  return {
    type: 'success',
    snapshot: {},
  };
};

const toolBarTopOffset = -38;

const getPartAndCapabilities = (
  selectedPartId: string,
  parts: AnyPartComponent[],
): (AnyPartComponent & { capabilities: PartCapabilities }) | null => {
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
      const partWithCapabilities = { ...part, capabilities };
      return partWithCapabilities;
    }
  }
  return null;
};

const LayoutEditor: React.FC<LayoutEditorProps> = (props) => {
  const pusherContext = useContext(NotificationContext);

  const pusher = useMemo(
    () => pusherContext || new EventEmitter().setMaxListeners(50),
    [pusherContext],
  );

  // The size of the current component *while* it's being resized before new size is, ignored if not actively resizing
  const [dragSize, setDragSize] = useState({ width: 0, height: 0 });
  const [isDragging, setIsDragging] = useState(false);

  const [parts, setParts] = useState(props.parts);

  const [configurePartId, setConfigurePartId] = useState('');

  const selectedPartId = props.selected || '';
  const selectedPartAndCapabilities = useMemo(
    () => getPartAndCapabilities(selectedPartId, parts),
    [selectedPartId, parts],
  );

  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);

  const fallbackPortalId = `part-portal-${props.id}`;
  const portalId = props.configurePortalId || fallbackPortalId;

  // this effect keeps the local parts state in sync with the props
  useEffect(() => {
    setParts(props.parts);
  }, [props.parts]);

  const toolbarPosition = { x: 0, y: 0 };
  if (selectedPartAndCapabilities) {
    const x = selectedPartAndCapabilities?.custom.x || 0;
    const y = (selectedPartAndCapabilities?.custom.y || 0) + toolBarTopOffset;
    toolbarPosition.x = x;
    toolbarPosition.y = y;
  }

  // this effect is to cover the case when the user is clicking "off" of a part to deselect it
  useEffect(() => {
    const handleHostClick = (e: any) => {
      const path = e.path || (e.composedPath && e.composedPath());
      const pathIds =
        path?.map((node: HTMLElement) => node.getAttribute && node.getAttribute('id')) || [];
      const classes = path?.map((node: HTMLElement) => node.className) || [];
      const isDraggable = classes.find((c: string) => c?.includes('draggable'));
      // console.log('HOST CLICK', { pathIds, path, e });
      const isToolbarClick = pathIds.includes(`active-selection-toolbar-${props.id}`);
      const isInConfigMode = configurePartId !== '';
      // TODO: ability to click things underneath other things using path and selection
      if (
        !isDraggable &&
        !isInConfigMode &&
        !isToolbarClick &&
        !parts.find((p) => pathIds.includes(p.id))
      ) {
        props.onSelect('');
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
  }, [props.id, props.hostRef, parts, configurePartId]);

  const handlePartClick = useCallback(
    async (e: any, payload: any) => {
      // console.log('AUTHOR PART CLICK', { payload, props });
      e.stopPropagation();
      if (selectedPartId === payload.id) {
        return;
      }
      props.onSelect(payload.id);
    },
    [props.onSelect, selectedPartId],
  );

  /**
   * Given a part ID, this will clone and modify values on part.custom and post the changes up the chain.
   *
   * Example:
   *   modifyPartCustomProp("part-123", { x: 100, y: 200 });
   */
  const modifyPartCustomProp = useCallback(
    (partId: string, modifications: Record<string, any>) => {
      const originalPart = parts.find((p: any) => p.id === partId);
      if (!originalPart) {
        console.error("Tried to modify part that doesn't exist", { partId, modifications });
        return;
      }

      if (!originalPart.custom) {
        console.error('Tried to modify part with no custom attribute', { part: originalPart });
        return;
      }

      const changes = Object.keys(modifications).filter(
        (key) => modifications[key] !== originalPart.custom[key],
      );

      if (changes.length === 0) {
        // console.log('No changes to make', { partId, modifications });
        return;
      }

      console.info('Modifying part ', partId, modifications);
      const newPart = clone(originalPart);
      newPart.custom = { ...originalPart.custom, ...modifications };
      const newParts = parts.map((p: any) => (p.id === partId ? newPart : p));

      // optimistically update parts
      setParts(newParts);

      // update parent with changes
      props.onChange(newParts);
    },
    [parts, props],
  );

  const handlePartResize = useCallback(
    ({
      partId,
      resizeData,
    }: {
      partId: string;
      resizeData: { x: number; y: number; width: number; height: number };
    }) => {
      const { width, height, x, y } = resizeData;
      modifyPartCustomProp(partId, { width, height, x, y });
      setIsDragging(false);
    },
    [modifyPartCustomProp],
  );

  const handlePartDrag = useCallback(
    ({ partId, dragData }: { partId: string; dragData: { x: number; y: number } }) => {
      const { x, y } = dragData;
      modifyPartCustomProp(partId, { x, y });
      setIsDragging(false);
    },
    [modifyPartCustomProp],
  );

  const handlePartConfigure = useCallback(
    async (partId, configure, context) => {
      /* console.log('LE: AUTHOR PART CONFIGURE', {
        configurePartId,
        partId,
        configure,
        portalId,
        context,
      }); */
      if (partId !== selectedPartId) {
        console.error('trying to enable configure for a not selected partId!');
        return;
      }
      if (configurePartId === partId && configure) {
        return;
      }

      if (configure) {
        if (props.onConfigurePart) {
          props.onConfigurePart(partId, context);
        }
        setConfigurePartId(partId);
      } else {
        setConfigurePartId('');
      }
    },
    [selectedPartId, configurePartId, portalId, pusher],
  );

  // the difference of this is that the toolbar just tells all the parts that this one is supposed to be in configuration mode
  // that should trigger them to fire their own onConfigure callbacks so that they can send part specific context
  const handleToolbarPartConfigure = (partId: string, configure: boolean) => {
    pusher.emit(NotificationType.CONFIGURE.toString(), { partId, configure });
  };

  const handlePartDelete = useCallback(async () => {
    // console.log('AUTHOR PART DELETE', { selectedPart }, selectedPartId);
    if (!selectedPartAndCapabilities) return;
    const filteredParts = parts.filter((part) => part.id !== selectedPartAndCapabilities.id);
    props.onChange(filteredParts, selectedPartId, true);
    // optimistically update local state
    setParts(filteredParts);
    // just setting the part ID should trigger the selectedPart also to get reset
    props.onSelect('');
  }, [selectedPartAndCapabilities, parts]);

  const DeleteComponentHandler = useCallback(() => {
    handlePartDelete();
    setShowConfirmDelete(false);
  }, [handlePartDelete]);

  const handleCopyComponent = useCallback(async () => {
    /* console.log('AUTHOR PART COPY', { selectedPart }); */
    if (props.onCopyPart) {
      props.onCopyPart(selectedPartAndCapabilities);
    }
    //dispatch(setCopiedPart({ copiedPart: selectedPart }));
  }, [selectedPartAndCapabilities, parts]);

  const handlePartMoveForward = useCallback(async () => {
    if (!selectedPartAndCapabilities) return;
    const part = parts.find((p: any) => p.id === selectedPartAndCapabilities.id);
    part?.custom &&
      modifyPartCustomProp(selectedPartAndCapabilities.id, { z: (part?.custom?.z || 0) + 1 });
  }, [selectedPartAndCapabilities, parts]);

  const handlePartMoveBack = useCallback(async () => {
    if (!selectedPartAndCapabilities) return;
    const part = parts.find((p: any) => p.id === selectedPartAndCapabilities.id);
    part?.custom &&
      modifyPartCustomProp(selectedPartAndCapabilities.id, {
        z: Math.max(0, (part?.custom?.z || 0) - 1),
      });
  }, [selectedPartAndCapabilities, parts]);

  const handlePartCancelConfigure = useCallback(
    async ({ id }: { id: string }) => {
      /* console.log('AUTHOR PART CANCEL CONFIGURE', { id, configurePartId }); */
      if (!configurePartId || id === configurePartId) {
        if (props.onCancelConfigurePart) {
          props.onCancelConfigurePart(configurePartId);
        }
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

        // console.log('LE:SAVE CONFIGURE', { id, snapshot, partsClone: clone(partsClone) });

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

  const handleShortcutActionNotifications = (payload: any) => {
    const { type } = payload;
    if (type === 'Delete') {
      setShowConfirmDelete(true);
    } else if (type === 'Copy') {
      handleCopyComponent();
    }
  };
  useEffect(() => {
    if (!pusher) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CONFIGURE,
      NotificationType.CONFIGURE_CANCEL,
      NotificationType.CONFIGURE_SAVE,
      NotificationType.CHECK_SHORTCUT_ACTIONS,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        // the layout renderer needs to handle some notifications to update the toolbar
        // and configuration portal if it's being used
        /* console.log(`LayoutEditor catching ${notificationType.toString()}`, { payload }); */
        switch (notificationType) {
          case NotificationType.CONFIGURE_CANCEL:
            handlePartCancelConfigure(payload);
            break;
          case NotificationType.CHECK_SHORTCUT_ACTIONS:
            handleShortcutActionNotifications(payload);
            break;
          case NotificationType.CONFIGURE_SAVE:
            // maybe layout editor should *only* do this for both cancel and save
            // because the part should also catch this event and call the onCancelConfigurePart
            if (!configurePartId || payload.id === configurePartId) {
              setConfigurePartId('');
            }
            break;
        }
      };
      const unsub = subscribeToNotification(pusher, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [configurePartId, handlePartCancelConfigure, selectedPartAndCapabilities, pusher]);

  const containerRef = useRef<HTMLDivElement>(null);

  const handlePartInit = async ({ id, responses }: { id: string; responses: any[] }) => {
    console.log('LE:PartInit', { id, responses });
    return {
      snapshot: {},
      context: {
        mode: contexts.AUTHOR,
        host: containerRef.current,
      },
    };
  };

  // Given a part ID and a model for that part, will return the model with the width & height
  // filled in if it's being actively dragged. This is so we can display the part-component properly
  // sized during the drag before the new width/height is committed.
  const decorateModelWithDragWidthHeight = useCallback(
    (partId: string, model: AnyPartModel) => {
      if (!isDragging) return model;
      if (partId !== selectedPartId) return model;
      return {
        ...model,
        ...dragSize,
      };
    },
    [dragSize, isDragging, selectedPartId],
  );

  return parts && parts.length ? (
    <NotificationContext.Provider value={pusher}>
      <div ref={containerRef} className="activity-content">
        <style>
          {`
          .activity-content {
            position: absolute;
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
            background-color: #fafafa;
            z-index: 999;
            min-width: 110px;
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
        `}
        </style>
        <div
          className="part-config-container"
          style={{ display: configurePartId.trim() ? 'block' : 'none' }}
          onClick={handlePortalBgClick}
        >
          <div id={fallbackPortalId} className="part-config-container-inner"></div>
        </div>
        <div
          id={`active-selection-toolbar-${props.id}`}
          className={`active-selection-toolbar ${selectedPartAndCapabilities?.type}`}
          style={{
            display: selectedPartAndCapabilities && !isDragging ? 'block' : 'none',
            top: toolbarPosition.y,
            left: toolbarPosition.x,
          }}
        >
          {selectedPartAndCapabilities && selectedPartAndCapabilities.capabilities.configure && (
            <button
              title="Edit"
              className="configure-toolbar-button"
              onClick={() => handleToolbarPartConfigure(selectedPartAndCapabilities.id, true)}
            >
              <i className="fas fa-edit"></i>
            </button>
          )}
          {selectedPartAndCapabilities && selectedPartAndCapabilities.capabilities.copy && (
            <button title="Copy" onClick={handleCopyComponent}>
              <i className="fas fa-copy"></i>
            </button>
          )}
          {/* <button title="Configure" onClick={handlePartConfigure}>
            <i className="fas fa-cog"></i>
          </button> */}
          {selectedPartAndCapabilities && selectedPartAndCapabilities.capabilities.move && (
            <button title="Move Forward" onClick={handlePartMoveForward}>
              <i className="fas fa-plus"></i>
            </button>
          )}
          {selectedPartAndCapabilities && selectedPartAndCapabilities.capabilities.move && (
            <button title="Move Back" onClick={handlePartMoveBack}>
              <i className="fas fa-minus"></i>
            </button>
          )}
          {selectedPartAndCapabilities && selectedPartAndCapabilities.capabilities.delete && (
            <button title="Delete" onClick={() => setShowConfirmDelete(true)}>
              <i className="fas fa-trash"></i>
            </button>
          )}
          <ConfirmDelete
            show={showConfirmDelete}
            elementType="Component"
            elementName={selectedPartAndCapabilities?.id}
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
            model: decorateModelWithDragWidthHeight(part.id, part.custom),
            state: {},
            configureMode: part.id === configurePartId,
            editMode: true,
            portal: portalId,
            onInit: handlePartInit,
            onReady: defaultHandler,
            onSave: defaultHandler,
            onSubmit: defaultHandler,
            onResize: defaultHandler,
          };

          const disableDrag =
            selectedPartAndCapabilities && !selectedPartAndCapabilities.capabilities.move;

          return (
            <ResizeContainer
              key={part.id}
              dragGrid={[5, 5]}
              resizeGrid={[1, 1]}
              selected={part.id === selectedPartId}
              size={{ width: part.custom.width || 100, height: part.custom.height || 100 }}
              position={{
                x: part.custom.x || 0,
                y: part.custom.y || 0,
              }}
              disabled={!!disableDrag}
              style={{ zIndex: part?.custom?.z || 0 }}
              onResizeStart={() => {
                props.onSelect(part.id);
                setDragSize({ width: part.custom.width || 0, height: part.custom.height || 0 });
                setIsDragging(true);
              }}
              onDragStart={() => {
                props.onSelect(part.id);
                setDragSize({ width: part.custom.width || 0, height: part.custom.height || 0 });
                setIsDragging(true);
              }}
              onDragStop={(e, d) => {
                handlePartDrag({ partId: part.id, dragData: d });
              }}
              onResize={(e, direction, ref) => {
                setDragSize({
                  width: parseInt(ref.style.width, 10),
                  height: parseInt(ref.style.height, 10),
                });
              }}
              onResizeStop={(e, direction, ref, delta, position) => {
                handlePartResize({
                  partId: part.id,
                  resizeData: {
                    width: parseInt(ref.style.width, 10),
                    height: parseInt(ref.style.height, 10),
                    x: Math.round(position.x),
                    y: Math.round(position.y),
                  },
                });
              }}
            >
              <PartComponent
                {...partProps}
                className={selectedPartId === part.id ? 'selected' : ''}
                onClick={(event) => handlePartClick(event, { id: part.id })}
                onConfigure={({ configure, context }) =>
                  handlePartConfigure(part.id, configure, context)
                }
                onSaveConfigure={handlePartSaveConfigure}
                onCancelConfigure={handlePartCancelConfigure}
              />
            </ResizeContainer>
          );
        })}
      </div>
    </NotificationContext.Provider>
  ) : null;
};

export default LayoutEditor;
