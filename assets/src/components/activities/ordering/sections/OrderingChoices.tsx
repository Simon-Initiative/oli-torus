import { Choice } from 'components/activities/types';
import { defaultWriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import {
  DragDropContext,
  Draggable,
  DraggableStateSnapshot,
  DraggingStyle,
  Droppable,
  NotDraggingStyle,
} from 'react-beautiful-dnd';
interface Props {
  setChoices: (choices: Choice[]) => void;
  choices: Choice[];
}
export const OrderingChoices: React.FC<Props> = ({ choices, setChoices }) => {
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

  return (
    <DragDropContext
      onDragEnd={({ destination, source }) => {
        if (
          !destination ||
          (destination.droppableId === source.droppableId && destination.index === source.index)
        ) {
          return;
        }

        const choice = choices[source.index];
        const newChoices = Array.from(choices);
        newChoices.splice(source.index, 1);
        newChoices.splice(destination.index, 0, choice);

        setChoices(newChoices);
      }}
    >
      <Droppable droppableId={'choices'}>
        {(provided) => (
          <div {...provided.droppableProps} className="mt-3" ref={provided.innerRef}>
            {choices.map((choice, index) => (
              <Draggable draggableId={choice.id} key={choice.id} index={index}>
                {(provided, snapshot) => (
                  <div
                    ref={provided.innerRef}
                    {...provided.draggableProps}
                    {...provided.dragHandleProps}
                    className="d-flex mb-3 align-items-center ordering-choice-card"
                    style={getStyle(provided.draggableProps.style, snapshot)}
                    aria-label={'Choice ' + index}
                    onKeyDown={(e) => {
                      console.log('e key', e.key, 'modifier', e.getModifierState('Shift'));
                      const newChoices = choices.slice();
                      newChoices.splice(index, 1);
                      if (e.key === 'ArrowUp' && e.getModifierState('Shift') && index > 0) {
                        console.log('choice', choice);
                        newChoices.splice(index - 1, 0, choice);
                        console.log('new choices', newChoices);
                        setChoices(newChoices);
                        e.stopPropagation();
                      }
                      if (
                        e.key === 'ArrowDown' &&
                        e.getModifierState('Shift') &&
                        index < choices.length - 1
                      ) {
                        newChoices.splice(index + 1, 0, choice);
                        setChoices(newChoices);
                        e.stopPropagation();
                      }
                    }}
                  >
                    <div
                      style={{
                        cursor: 'move',
                        width: 24,
                        color: 'rgba(0,0,0,0.26)',
                        marginRight: '0.5rem',
                      }}
                      className="material-icons"
                    >
                      drag_indicator
                    </div>
                    <div style={{ marginRight: '0.5rem' }}>{index + 1}.</div>
                    <HtmlContentModelRenderer
                      text={choice.content}
                      context={defaultWriterContext()}
                    />
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
