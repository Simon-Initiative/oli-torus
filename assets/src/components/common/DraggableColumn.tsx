import React, { PropsWithChildren } from 'react';
import {
  DragDropContext,
  Draggable as DraggableDND,
  DraggableStateSnapshot,
  DraggingStyle,
  Droppable,
  DropResult,
  NotDraggingStyle,
} from 'react-beautiful-dnd';
import { ClassName, classNames } from 'utils/classNames';
import guid from 'utils/guid';

import styles from './DraggableColumn.modules.scss';

interface DragIndicatorProps
  extends PropsWithChildren<{
    isDragDisabled?: boolean;
  }> {}
const DragIndicator: React.FC<DragIndicatorProps> = ({ isDragDisabled }) => {
  return (
    <div className={classNames(styles.draggableColumnIndicator, isDragDisabled && styles.disabled)}>
      <i className="fa-solid fa-grip-vertical"></i>
    </div>
  );
};
interface ItemProps {
  className?: ClassName;
  id: string;
  itemAriaLabel?: string;
  item: any;
  children: (item: any, index: number) => React.ReactNode;

  setItems?: (items: any[]) => void;
  items?: any[];
  index?: number;
  displayOutline?: boolean;
  isDragDisabled?: boolean;
}
const Item: React.FC<ItemProps> = ({
  id,
  className,
  index = 0,
  itemAriaLabel,
  item,
  items = [],
  setItems = () => undefined,
  children,
  displayOutline,
  isDragDisabled,
}) => {
  return (
    <DraggableDND draggableId={id} key={id} index={index} isDragDisabled={isDragDisabled ?? false}>
      {(provided, snapshot) => (
        <div
          ref={provided.innerRef}
          {...provided.draggableProps}
          {...provided.dragHandleProps}
          className={classNames(
            className,
            styles.draggableColumnCard,
            displayOutline ? styles.draggableColumnOutlined : null,
          )}
          style={getStyle(provided.draggableProps.style, snapshot)}
          aria-label={itemAriaLabel || 'Item ' + index}
          onKeyDown={(e: any) => reorderByKey(e, index, items, item, setItems)}
        >
          {children(item, index)}
        </div>
      )}
    </DraggableDND>
  );
};

interface ColumnProps {
  setItems: (items: any[]) => void;
  items: any[];
  displayOutline?: boolean;
}
export const Column: React.FC<ColumnProps> = ({ items, setItems, children, displayOutline }) => {
  return (
    <DragDropContext onDragEnd={(result) => reorderByMouse(result, items, setItems)}>
      <Droppable droppableId={'items-' + guid()}>
        {(provided) => (
          <div
            {...provided.droppableProps}
            className={styles.draggableColumnContainer}
            ref={provided.innerRef}
          >
            {React.Children.map(children, (c, index) =>
              React.isValidElement(c) && c.type === Item ? (
                <Item
                  displayOutline={displayOutline}
                  {...c.props}
                  index={index}
                  items={items}
                  setItems={setItems}
                />
              ) : (
                c
              ),
            )}
            {provided.placeholder}
          </div>
        )}
      </Droppable>
    </DragDropContext>
  );
};

const getStyle = (
  style: DraggingStyle | NotDraggingStyle | undefined,
  snapshot: DraggableStateSnapshot,
) => {
  const snapshotStyle = snapshot.draggingOver ? ({ pointerEvents: 'none' } as any) : {};
  if (style?.transform) {
    const axisLockY = `translate(0px, ${style.transform.split(',').pop()}`;
    return {
      ...style,
      ...snapshotStyle,
      minHeight: 41,
      transform: axisLockY,
    };
  }
  return {
    ...style,
    ...snapshotStyle,
    minHeight: 41,
  };
};

const reorderByMouse = (
  { destination, source }: DropResult,
  items: unknown[],
  setItems: (is: unknown[]) => void,
): void => {
  if (
    !destination ||
    (destination.droppableId === source.droppableId && destination.index === source.index)
  ) {
    return;
  }

  const item = items[source.index];
  const newItems = Array.from(items);
  newItems.splice(source.index, 1);
  newItems.splice(destination.index, 0, item);

  setItems(newItems);
};

const reorderByKey = (
  e: React.KeyboardEvent<HTMLDivElement>,
  index: number,
  items: any[],
  item: any,
  setItems: (is: any[]) => void,
) => {
  if (
    (e.key === 'ArrowUp' && e.getModifierState('Shift')) ||
    (e.key === 'ArrowDown' && e.getModifierState('Shift'))
  ) {
    const newItems = items.slice();
    newItems.splice(index, 1);
    e.stopPropagation();

    if (e.key === 'ArrowUp' && index > 0) {
      newItems.splice(index - 1, 0, item);
    }
    if (e.key === 'ArrowDown' && index < items.length - 1) {
      newItems.splice(index + 1, 0, item);
    }
    setItems(newItems);
  }
};

export const Draggable = {
  Column,
  Item,
  DragIndicator,
};
