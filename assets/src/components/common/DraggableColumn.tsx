import React from 'react';
import {
  DragDropContext,
  Draggable as DraggableDND,
  DraggableStateSnapshot,
  DraggingStyle,
  Droppable,
  DropResult,
  NotDraggingStyle,
} from 'react-beautiful-dnd';
import guid from 'utils/guid';
import './DraggableColumn.scss';

const DragIndicator: React.FC = () => {
  return <div className="material-icons draggableColumn__dragIndicator">drag_indicator</div>;
};
interface ItemProps {
  id: string;
  itemAriaLabel?: string;
  item: any;
  children: (item: any, index: number) => React.ReactNode;

  setItems?: (items: any[]) => void;
  items?: any[];
  index?: number;
}
const Item: React.FC<ItemProps> = ({
  id,
  index = 0,
  itemAriaLabel,
  item,
  items = [],
  setItems = () => undefined,
  children,
}) => {
  return (
    <DraggableDND draggableId={id} key={id} index={index}>
      {(provided, snapshot) => (
        <div
          ref={provided.innerRef}
          {...provided.draggableProps}
          {...provided.dragHandleProps}
          className="draggableColumn__card"
          style={getStyle(provided.draggableProps.style, snapshot)}
          aria-label={itemAriaLabel || 'Item ' + index}
          onKeyDown={(e) => reorderByKey(e, index, items, item, setItems)}
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
}
export const Column: React.FC<ColumnProps> = ({ items, setItems, children }) => {
  return (
    <DragDropContext onDragEnd={(result) => reorderByMouse(result, items, setItems)}>
      <Droppable droppableId={'items-' + guid()}>
        {(provided) => (
          <div
            {...provided.droppableProps}
            className="draggableColumn__container"
            ref={provided.innerRef}
          >
            {React.Children.map(children, (c, index) =>
              React.isValidElement(c) && c.type === Item ? (
                <Item {...c.props} index={index} items={items} setItems={setItems} />
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
  const snapshotStyle = snapshot.draggingOver ? { 'pointer-events': 'none' } : {};
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
