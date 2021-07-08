import { Identifiable } from 'data/content/model';
import React from 'react';
import {
  DragDropContext,
  Draggable,
  DraggableStateSnapshot,
  DraggingStyle,
  Droppable,
  NotDraggingStyle,
} from 'react-beautiful-dnd';
import guid from 'utils/guid';
import './DraggableColumn.scss';

interface Props {
  setItems: (items: Identifiable[]) => void;
  items: Identifiable[];
}
export const DraggableColumn: React.FC<Props> = ({ items, setItems, children }) => {
  return (
    <DragDropContext
      onDragEnd={({ destination, source }) => {
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
      }}
    >
      <Droppable droppableId={'items-' + guid()}>
        {(provided) => (
          <div {...provided.droppableProps} className="mt-3" ref={provided.innerRef}>
            {items.map((item, index) => (
              <Draggable draggableId={item.id} key={item.id} index={index}>
                {(provided, snapshot) => (
                  <div
                    ref={provided.innerRef}
                    {...provided.draggableProps}
                    {...provided.dragHandleProps}
                    className="d-flex mb-3 align-items-center ordering-choice-card"
                    style={getStyle(provided.draggableProps.style, snapshot)}
                    aria-label={'Item ' + index}
                    onKeyDown={(e) => {
                      const newItems = items.slice();
                      newItems.splice(index, 1);
                      if (e.key === 'ArrowUp' && e.getModifierState('Shift') && index > 0) {
                        newItems.splice(index - 1, 0, item);
                        setItems(newItems);
                        e.stopPropagation();
                      }
                      if (
                        e.key === 'ArrowDown' &&
                        e.getModifierState('Shift') &&
                        index < items.length - 1
                      ) {
                        newItems.splice(index + 1, 0, item);
                        setItems(newItems);
                        e.stopPropagation();
                      }
                    }}
                  >
                    <div
                      style={{
                        width: 24,
                        color: 'rgba(0,0,0,0.26)',
                        marginRight: '0.5rem',
                      }}
                      className="material-icons"
                    >
                      drag_indicator
                    </div>
                    {children}
                  </div>
                )}
              </Draggable>
            ))}
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
