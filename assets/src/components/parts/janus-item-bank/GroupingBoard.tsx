import React, { useMemo, useRef, useState } from 'react';
import {
  Announcements,
  DndContext,
  DragCancelEvent,
  DragEndEvent,
  DragOverEvent,
  DragOverlay,
  DragStartEvent,
  KeyboardSensor,
  PointerSensor,
  TouchSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
} from '@dnd-kit/core';
import { CSS } from '@dnd-kit/utilities';
import GroupingItemContent from './GroupingItemContent';
import {
  GROUPING_KEYBOARD_CODES,
  GroupingKeyboardTarget,
  confirmGroupingKeyboardTarget,
  createGroupingKeyboardCoordinates,
  groupingPointerCollision,
  snapCenterToCursor,
} from './grouping-dnd';
import {
  BANK_ID,
  BANK_LABEL,
  Placements,
  categoryTitle,
  groupingThemeStyles,
  isItemCorrect,
  itemAccessibleText,
  itemsInZone,
} from './grouping-util';
import { GroupingItem, GroupingModel } from './schema';

const GROUPING_KEYBOARD_INSTRUCTIONS =
  'Move items from the Item Bank into categories. Tab to an item, then press Space or Enter to pick it up. While moving, use Tab, Right Arrow, or Down Arrow for the next location, and Shift plus Tab, Left Arrow, or Up Arrow for the previous location. Press Space or Enter to drop the item, or Escape to cancel.';

const HintBadge: React.FC<{ type: 'correct' | 'incorrect' }> = ({ type }) => (
  <span className={`grouping-hint-badge is-${type}`} aria-hidden="true">
    <svg viewBox="0 0 12 12" width="12" height="12" focusable="false" aria-hidden="true">
      {type === 'correct' ? (
        <path
          d="M2.5 6.25 4.75 8.5 9.5 3.75"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.75"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      ) : (
        <>
          <path
            d="M3.25 3.25 8.75 8.75"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.75"
            strokeLinecap="round"
          />
          <path
            d="M8.75 3.25 3.25 8.75"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.75"
            strokeLinecap="round"
          />
        </>
      )}
    </svg>
  </span>
);

interface DraggableItemProps {
  item: GroupingItem;
  zoneId: string;
  zoneLabel: string;
  enabled: boolean;
  hint?: 'correct' | 'incorrect' | null;
}

const DraggableItem: React.FC<DraggableItemProps> = ({
  item,
  zoneId,
  zoneLabel,
  enabled,
  hint,
}) => {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: item.id,
    data: { zoneId },
    disabled: !enabled,
  });

  const style: React.CSSProperties = isDragging
    ? { opacity: 0 }
    : { transform: CSS.Translate.toString(transform) };

  const classes = ['grouping-item', `grouping-item-${item.type}`];
  if (isDragging) {
    classes.push('is-dragging');
  }
  if (!enabled) {
    classes.push('is-disabled');
  }
  if (hint === 'correct') {
    classes.push('is-correct');
  }
  if (hint === 'incorrect') {
    classes.push('is-incorrect');
  }

  const describedText = `${itemAccessibleText(item)}, currently in ${zoneLabel}.`;

  return (
    <div
      ref={setNodeRef}
      className={classes.join(' ')}
      style={style}
      {...(enabled ? listeners : {})}
      {...attributes}
      tabIndex={enabled ? 0 : -1}
      aria-label={describedText}
      aria-describedby={undefined}
      aria-roledescription={enabled ? attributes['aria-roledescription'] : undefined}
      aria-disabled={!enabled}
    >
      {hint === 'correct' && <HintBadge type="correct" />}
      {hint === 'incorrect' && <HintBadge type="incorrect" />}
      <GroupingItemContent item={item} imageDecorative />
    </div>
  );
};

interface DropZoneProps {
  domId: string;
  zoneId: string;
  title: string;
  isBank: boolean;
  enabled: boolean;
  children: React.ReactNode;
  itemCount: number;
}

const DropZone: React.FC<DropZoneProps> = ({
  domId,
  zoneId,
  title,
  isBank,
  enabled,
  children,
  itemCount,
}) => {
  const { setNodeRef, isOver } = useDroppable({ id: zoneId, disabled: !enabled });
  const columnClasses = ['grouping-column'];
  if (isBank) {
    columnClasses.push('grouping-column-bank');
  }
  const dropzoneClasses = ['grouping-dropzone'];
  if (isBank) {
    dropzoneClasses.push('grouping-dropzone-bank');
  }
  if (isOver) {
    dropzoneClasses.push('over');
  }
  return (
    <section
      className={columnClasses.join(' ')}
      aria-label={`${title}, ${itemCount} item${itemCount === 1 ? '' : 's'}`}
    >
      <header className="grouping-column-header">{title}</header>
      <div
        id={domId}
        ref={setNodeRef}
        className={dropzoneClasses.join(' ')}
        aria-dropeffect={enabled ? 'move' : undefined}
      >
        {children}
        {itemCount === 0 && (
          <div className="grouping-empty-hint" aria-hidden="true">
            <span>{isBank || !enabled ? 'No items' : 'Drop items here'}</span>
          </div>
        )}
      </div>
    </section>
  );
};

export interface GroupingBoardProps {
  id: string;
  model: GroupingModel;
  placements: Placements;
  onMove: (itemId: string, zoneId: string) => void;
  enabled?: boolean;
  // when true, mark each placed item with a correct/incorrect hint
  showHints?: boolean;
}

/**
 * Learner-facing drag-and-drop board used by delivery and live preview. Supports
 * mouse, touch and keyboard via dnd-kit sensors and announces moves to screen readers.
 */
const GroupingBoard: React.FC<GroupingBoardProps> = ({
  id,
  model,
  placements,
  onMove,
  enabled = true,
  showHints = false,
}) => {
  const [activeItem, setActiveItem] = useState<GroupingItem | null>(null);
  const [activeOverlayWidth, setActiveOverlayWidth] = useState<number | undefined>(undefined);
  const keyboardTarget = useRef<GroupingKeyboardTarget>({ current: null, pending: null });
  const instructionsId = `${id}-grouping-instructions`;
  const zoneDomId = (zoneId: string) => `${id}-grouping-zone-${zoneId}`;
  const keyboardCoordinates = useMemo(
    () =>
      createGroupingKeyboardCoordinates(
        [BANK_ID, ...(model.categories || []).map((category) => category.id)],
        keyboardTarget.current,
      ),
    [model.categories],
  );

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 150, tolerance: 6 } }),
    useSensor(KeyboardSensor, {
      keyboardCodes: GROUPING_KEYBOARD_CODES,
      coordinateGetter: keyboardCoordinates,
      scrollBehavior: 'auto',
    }),
  );

  const zoneLabel = (zoneId: string): string => {
    if (zoneId === BANK_ID) {
      return BANK_LABEL;
    }
    const idx = (model.categories || []).findIndex((c) => c.id === zoneId);
    return idx === -1 ? BANK_LABEL : categoryTitle(model.categories[idx], idx);
  };

  const findItem = (itemId: string): GroupingItem | undefined =>
    (model.items || []).find((i) => i.id === itemId);

  const clearDragState = () => {
    setActiveItem(null);
    setActiveOverlayWidth(undefined);
    keyboardTarget.current.current = null;
    keyboardTarget.current.pending = null;
  };

  const scrollZoneIntoView = (zoneId: string) => {
    document
      .getElementById(zoneDomId(zoneId))
      ?.scrollIntoView?.({ behavior: 'auto', block: 'nearest', inline: 'nearest' });
  };

  const handleDragStart = (event: DragStartEvent) => {
    const item = findItem(`${event.active.id}`);
    keyboardTarget.current.current = `${event.active.data.current?.zoneId || BANK_ID}`;
    keyboardTarget.current.pending = null;
    setActiveItem(item || null);
    const rect = event.active.rect.current.initial;
    setActiveOverlayWidth(rect ? Math.round(rect.width) : undefined);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    const itemId = `${active.id}`;
    const currentZone = placements[itemId] || BANK_ID;
    clearDragState();
    if (!over) {
      scrollZoneIntoView(currentZone);
      return;
    }
    const targetZone = `${over.id}`;
    if (targetZone !== currentZone) {
      onMove(itemId, targetZone);
    } else {
      scrollZoneIntoView(currentZone);
    }
  };

  const handleDragCancel = (event: DragCancelEvent) => {
    const sourceZone = `${event.active.data.current?.zoneId || BANK_ID}`;
    clearDragState();
    scrollZoneIntoView(sourceZone);
  };

  const handleDragOver = (event: DragOverEvent) => {
    const overId = event.over ? `${event.over.id}` : null;
    if (overId && confirmGroupingKeyboardTarget(keyboardTarget.current, overId)) {
      scrollZoneIntoView(overId);
    }
  };

  const announcements: Announcements = {
    onDragStart({ active }) {
      const item = findItem(`${active.id}`);
      const itemText = item ? itemAccessibleText(item) : `${active.id}`;
      const currentZone = `${active.data.current?.zoneId || BANK_ID}`;
      return `Picked up ${itemText}. Current location: ${zoneLabel(currentZone)}.`;
    },
    onDragOver({ active, over }) {
      const item = findItem(`${active.id}`);
      const itemText = item ? itemAccessibleText(item) : `${active.id}`;
      if (over) {
        return `${itemText}. Current location: ${zoneLabel(`${over.id}`)}.`;
      }
      return `${itemText}. Not over a valid location.`;
    },
    onDragEnd({ active, over }) {
      const item = findItem(`${active.id}`);
      const itemText = item ? itemAccessibleText(item) : `${active.id}`;
      if (over) {
        return `${itemText} dropped in ${zoneLabel(`${over.id}`)}.`;
      }
      return `${itemText} was not moved.`;
    },
    onDragCancel({ active }) {
      const item = findItem(`${active.id}`);
      const itemText = item ? itemAccessibleText(item) : `${active.id}`;
      const currentZone = `${active.data.current?.zoneId || BANK_ID}`;
      return `Move cancelled. ${itemText} remains in ${zoneLabel(currentZone)}.`;
    },
  };

  const hintFor = (itemId: string): 'correct' | 'incorrect' | null => {
    if (!showHints) {
      return null;
    }
    return isItemCorrect(model, placements, itemId) ? 'correct' : 'incorrect';
  };

  const renderZone = (zoneId: string, title: string, isBank: boolean) => {
    const zoneItems = itemsInZone(model, placements, zoneId);
    return (
      <DropZone
        key={zoneId}
        domId={zoneDomId(zoneId)}
        zoneId={zoneId}
        title={title}
        isBank={isBank}
        enabled={enabled}
        itemCount={zoneItems.length}
      >
        {zoneItems.map((item) => (
          <DraggableItem
            key={item.id}
            item={item}
            zoneId={zoneId}
            zoneLabel={title}
            enabled={enabled}
            hint={isBank ? null : hintFor(item.id)}
          />
        ))}
      </DropZone>
    );
  };

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={groupingPointerCollision}
      accessibility={{
        announcements,
        screenReaderInstructions: { draggable: '' },
      }}
      onDragStart={handleDragStart}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
      onDragCancel={handleDragCancel}
    >
      {enabled ? (
        <span id={instructionsId} className="grouping-visually-hidden">
          {GROUPING_KEYBOARD_INSTRUCTIONS}
        </span>
      ) : null}
      <div
        className="grouping-columns grouping-board-introduction"
        role="group"
        aria-label="Grouping activity"
        aria-describedby={enabled ? instructionsId : undefined}
        tabIndex={enabled ? 0 : -1}
      >
        {renderZone(BANK_ID, BANK_LABEL, true)}
        {(model.categories || []).map((category, index) =>
          renderZone(category.id, categoryTitle(category, index), false),
        )}
      </div>
      <DragOverlay
        className="grouping-drag-overlay"
        style={groupingThemeStyles(model.themeColor)}
        dropAnimation={null}
        modifiers={[snapCenterToCursor]}
      >
        {activeItem ? (
          <div
            className={`grouping-item grouping-item-${activeItem.type} is-overlay`}
            style={activeOverlayWidth ? { width: activeOverlayWidth } : undefined}
            aria-hidden="true"
          >
            <GroupingItemContent item={activeItem} imageDecorative />
          </div>
        ) : null}
      </DragOverlay>
    </DndContext>
  );
};

export default GroupingBoard;
