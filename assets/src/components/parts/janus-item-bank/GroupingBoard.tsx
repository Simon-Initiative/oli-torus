import React, { useState } from 'react';
import {
  Announcements,
  DndContext,
  DragEndEvent,
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
import { groupingPointerCollision, snapCenterToCursor } from './grouping-dnd';
import {
  BANK_ID,
  BANK_LABEL,
  Placements,
  categoryTitle,
  groupingThemeStyles,
  isItemCorrect,
  itemsInZone,
} from './grouping-util';
import { GroupingItem, GroupingModel } from './schema';

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
  if (hint === 'correct') {
    classes.push('is-correct');
  }
  if (hint === 'incorrect') {
    classes.push('is-incorrect');
  }

  const describedText = `${item.label}, currently in ${zoneLabel}.${
    enabled ? ' Press space or enter to pick up.' : ''
  }`;

  return (
    <div
      ref={setNodeRef}
      className={classes.join(' ')}
      style={style}
      {...(enabled ? listeners : {})}
      {...attributes}
      tabIndex={enabled ? 0 : -1}
      aria-label={describedText}
      aria-disabled={!enabled}
      aria-hidden={isDragging}
    >
      {hint === 'correct' && <HintBadge type="correct" />}
      {hint === 'incorrect' && <HintBadge type="incorrect" />}
      <GroupingItemContent item={item} />
    </div>
  );
};

interface DropZoneProps {
  zoneId: string;
  title: string;
  isBank: boolean;
  children: React.ReactNode;
  itemCount: number;
}

const DropZone: React.FC<DropZoneProps> = ({ zoneId, title, isBank, children, itemCount }) => {
  const { setNodeRef, isOver } = useDroppable({ id: zoneId });
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
      <div ref={setNodeRef} className={dropzoneClasses.join(' ')} aria-dropeffect="move">
        {children}
        {itemCount === 0 && (
          <div className="grouping-empty-hint" aria-hidden="true">
            <span>{isBank ? 'No items' : 'Drop items here'}</span>
          </div>
        )}
      </div>
    </section>
  );
};

export interface GroupingBoardProps {
  model: GroupingModel;
  placements: Placements;
  onMove: (itemId: string, zoneId: string) => void;
  enabled?: boolean;
  // when true, mark each placed item with a correct/incorrect hint
  showHints?: boolean;
}

/**
 * Shared accessible drag-and-drop board used by both the delivery component and
 * the authoring "Set Answer" view. Supports mouse, touch and keyboard via
 * dnd-kit sensors and announces moves to screen readers.
 */
const GroupingBoard: React.FC<GroupingBoardProps> = ({
  model,
  placements,
  onMove,
  enabled = true,
  showHints = false,
}) => {
  const [activeItem, setActiveItem] = useState<GroupingItem | null>(null);
  const [activeOverlayWidth, setActiveOverlayWidth] = useState<number | undefined>(undefined);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 150, tolerance: 6 } }),
    useSensor(KeyboardSensor),
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
  };

  const handleDragStart = (event: DragStartEvent) => {
    const item = findItem(`${event.active.id}`);
    setActiveItem(item || null);
    const rect = event.active.rect.current.initial;
    setActiveOverlayWidth(rect ? Math.round(rect.width) : undefined);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    clearDragState();
    const { active, over } = event;
    if (!over) {
      return;
    }
    const itemId = `${active.id}`;
    const targetZone = `${over.id}`;
    const currentZone = placements[itemId] || BANK_ID;
    if (targetZone !== currentZone) {
      onMove(itemId, targetZone);
    }
  };

  const announcements: Announcements = {
    onDragStart({ active }) {
      const item = findItem(`${active.id}`);
      return `Picked up item ${item?.label ?? active.id}.`;
    },
    onDragOver({ active, over }) {
      const item = findItem(`${active.id}`);
      if (over) {
        return `Item ${item?.label ?? active.id} is over ${zoneLabel(`${over.id}`)}.`;
      }
      return `Item ${item?.label ?? active.id} is no longer over a drop area.`;
    },
    onDragEnd({ active, over }) {
      const item = findItem(`${active.id}`);
      if (over) {
        return `Item ${item?.label ?? active.id} was dropped into ${zoneLabel(`${over.id}`)}.`;
      }
      return `Item ${item?.label ?? active.id} was dropped.`;
    },
    onDragCancel({ active }) {
      const item = findItem(`${active.id}`);
      return `Dragging item ${item?.label ?? active.id} was cancelled.`;
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
        zoneId={zoneId}
        title={title}
        isBank={isBank}
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
      accessibility={{ announcements }}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
      onDragCancel={clearDragState}
    >
      <div className="grouping-columns">
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
          >
            <GroupingItemContent item={activeItem} />
          </div>
        ) : null}
      </DragOverlay>
    </DndContext>
  );
};

export default GroupingBoard;
