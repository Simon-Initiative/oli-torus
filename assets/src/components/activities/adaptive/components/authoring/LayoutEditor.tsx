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
  responsiveLayout?: boolean;
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

  useEffect(() => {
    if (!parts?.length) {
      setParts([
        {
          id: '__default',
          type: 'janus-text-flow',
          custom: [],
        },
      ]);
    }
  }, [parts]);

  const isResponsive = props.responsiveLayout || false;
  const containerRef = useRef<HTMLDivElement>(null);

  // Calculate toolbar position
  const getToolbarPosition = () => {
    if (!selectedPartAndCapabilities) return { x: 0, y: 0 };

    if (isResponsive) {
      // In responsive mode, position toolbar at the top of the selected part
      const selectedPartElement = document.querySelector(
        `[data-part-id="${selectedPartAndCapabilities.id}"]`,
      );
      if (selectedPartElement && containerRef.current) {
        const rect = selectedPartElement.getBoundingClientRect();
        const containerRect = containerRef.current.getBoundingClientRect();
        return {
          x: rect.left - containerRect.left,
          y: rect.top - containerRect.top + toolBarTopOffset,
        };
      } else {
        // Fallback: use a default position if element not found
        console.warn('Selected part element not found, using fallback position');
        return { x: 100, y: 100 };
      }
    } else {
      // In non-responsive mode, use the part's x,y coordinates
      const x = selectedPartAndCapabilities?.custom.x || 0;
      const y = (selectedPartAndCapabilities?.custom.y || 0) + toolBarTopOffset;
      return { x, y };
    }
  };

  const [toolbarPosition, setToolbarPosition] = useState({ x: 0, y: 0 });

  // Helper function to render individual parts
  const renderPart = (part: AnyPartComponent, idx: number) => {
    // For images with only lockAspectRatio (no scaleContent), preserve original width to maintain aspect ratio
    const isImageWithOnlyLockAspectRatio =
      isResponsive &&
      part.type === 'janus-image' &&
      part.custom.lockAspectRatio === true &&
      !part.custom.scaleContent;

    const partProps = {
      id: part.id,
      type: part.type,
      model: {
        ...decorateModelWithDragWidthHeight(part.id, part.custom),
        // In responsive mode, set width to 100% for all parts EXCEPT images with only lockAspectRatio
        // Images with only lockAspectRatio keep original width to maintain aspect ratio
        width: isResponsive && !isImageWithOnlyLockAspectRatio ? '100%' : part.custom.width,
        // Preserve original x & y positions in the model (they will be ignored in rendering)
        x: part.custom.x || 0,
        y: part.custom.y || 0,
      },
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

    // Determine position and size based on responsive mode
    const position = isResponsive
      ? { x: 0, y: 0 } // Ignore x,y positions in responsive mode (but preserve in model)
      : { x: part.custom.x || 0, y: part.custom.y || 0 };

    const size = {
      width: part.custom.width || 100,
      height: part.custom.height || 100,
    };

    // Determine resize grid based on responsive mode
    const resizeGrid: [number, number] = isResponsive ? [0, 1] : [1, 1]; // Only vertical resize in responsive mode

    const handleDragStop = (e: any, d: any) => {
      handlePartDrag({ partId: part.id, dragData: d });
    };

    const handleResizeStop = (e: any, direction: any, ref: any, delta: any, position: any) => {
      handlePartResize({
        partId: part.id,
        resizeData: {
          width: isResponsive
            ? getWidth(part.custom.width) || 100 // Keep original width in responsive mode
            : parseInt(ref.style.width, 10), // Use actual width in non-responsive mode
          height: parseInt(ref.style.height, 10),
          x: Math.round(position.x), // Always update x position in data
          y: Math.round(position.y), // Always update y position in data
        },
      });
    };

    return (
      <ResizeContainer
        key={part.id}
        dragGrid={[5, 5]}
        resizeGrid={resizeGrid}
        selected={part.id === selectedPartId}
        size={size}
        position={position}
        disabled={!!disableDrag}
        style={{ zIndex: part?.custom?.z || 0 }}
        onResizeStart={() => {
          props.onSelect(part.id);
          setDragSize({
            width: getWidth(part.custom.width) || 0,
            height: part.custom.height || 0,
          });
          setIsDragging(true);
        }}
        onDragStart={() => {
          props.onSelect(part.id);
          setDragSize({
            width: getWidth(part.custom.width) || 0,
            height: part.custom.height || 0,
          });
          setIsDragging(true);
        }}
        onDragStop={handleDragStop}
        onResize={(e, direction, ref) => {
          setDragSize({
            width: parseInt(ref.style.width, 10),
            height: parseInt(ref.style.height, 10),
          });
        }}
        onResizeStop={handleResizeStop}
      >
        <PartComponent
          {...partProps}
          className={selectedPartId === part.id ? 'selected' : ''}
          onClick={(event) => handlePartClick(event, { id: part.id })}
          onConfigure={({ configure, context }) => handlePartConfigure(part.id, configure, context)}
          onSaveConfigure={handlePartSaveConfigure}
          onCancelConfigure={handlePartCancelConfigure}
        />
      </ResizeContainer>
    );
  };

  // Update toolbar position when selection changes
  useEffect(() => {
    if (selectedPartAndCapabilities) {
      const updatePosition = () => {
        const newPosition = getToolbarPosition();
        setToolbarPosition(newPosition);
      };

      // Update immediately
      updatePosition();

      // Update after a short delay to ensure DOM is ready
      const timeoutId = setTimeout(updatePosition, 10);

      return () => clearTimeout(timeoutId);
    } else {
      setToolbarPosition({ x: 0, y: 0 });
    }
  }, [selectedPartAndCapabilities, isResponsive]);

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

  const handlePartInit = async ({ id, responses }: { id: string; responses: any[] }) => {
    return {
      snapshot: {},
      context: {
        mode: contexts.AUTHOR,
        host: containerRef.current,
        responsiveLayout: isResponsive,
      },
    };
  };

  const getWidth = (width: any) => {
    if (typeof width === 'number') {
      return width;
    }
    if (width === '100%') {
      return 960;
    }
    return 470;
  };
  // Given a part ID and a model for that part, will return the model with the width & height
  // filled in if it's being actively dragged. This is so we can display the part-component properly
  // sized during the drag before the new width/height is committed .
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
      <div
        ref={containerRef}
        className={`activity-content ${isResponsive ? 'responsive-layout-active' : ''}`}
      >
        <style>
          {`
            .activity-content {
              ${isResponsive ? 'position: relative;' : 'position: absolute;'}
              border: 1px solid #ccc;
              background-color: ${props.backgroundColor || '#fff'};
              ${
                isResponsive
                  ? `max-width: ${
                      props.width || 1200
                    }px; min-width: 1000px; height: auto; min-height: auto; box-sizing: border-box;`
                  : `width: ${props.width || 1000}px; height: ${
                      props?.height || 500
                    }px; min-height: 500px;`
              }
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
            display: selectedPartAndCapabilities ? 'block' : 'none',
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
        {isResponsive ? (
          <div className="advance-authoring-responsive-layout">
            {parts.map((part: AnyPartComponent, idx: number) => {
              // Determine width class and alignment for responsive layout using responsiveLayoutWidth
              const responsiveWidth = part.custom.responsiveLayoutWidth || 960; // Default to 100% if not set
              const widthClass =
                responsiveWidth === 960 ||
                responsiveWidth === '100%' ||
                typeof responsiveWidth !== 'number' ||
                responsiveWidth === undefined ||
                responsiveWidth === null
                  ? 'full-width'
                  : 'half-width';
              const alignmentClass =
                responsiveWidth === 471 ? 'responsive-align-right' : 'responsive-align-left';

              return (
                <div
                  key={part.id}
                  data-part-id={part.id}
                  style={{ height: 'auto', minHeight: 'fit-content' }}
                  className={`responsive-item ${widthClass} ${alignmentClass}`}
                >
                  {renderPart(part, idx)}
                </div>
              );
            })}
          </div>
        ) : (
          parts.map((part, idx) => renderPart(part, idx))
        )}
      </div>
    </NotificationContext.Provider>
  ) : (
    <div className="activity-no-part-content"></div>
  );
};

export default LayoutEditor;
