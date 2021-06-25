import React from 'react';
import { DragDropContext, Droppable } from 'react-beautiful-dnd';
import { Choice, RichText } from 'components/activities/types';
import { ChoiceAuthoringConnected } from 'components/activities/common/choices/ChoiceAuthoring';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';

interface Props {
  icon: React.ReactNode;
  choices: Choice[];
  addOne: () => void;
  setAll: (choices: Choice[]) => void;
  onEdit: (id: string, content: RichText) => void;
  onRemove: (id: string) => void;
}
export const ChoicesAuthoringConnected: React.FC<Props> = ({
  icon,
  choices,
  addOne,
  setAll,
  onEdit,
  onRemove,
}) => {
  return (
    <>
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

          setAll(newChoices);
        }}
      >
        <Droppable droppableId={'choices'}>
          {(provided) => (
            <div {...provided.droppableProps} className="mt-3" ref={provided.innerRef}>
              {choices.map((choice, index) => (
                <ChoiceAuthoringConnected
                  icon={icon}
                  key={index + 'choice'}
                  index={index}
                  choice={choice}
                  canRemove={choices.length > 1}
                  onEdit={onEdit}
                  onRemove={onRemove}
                />
              ))}
              {provided.placeholder}
            </div>
          )}
        </Droppable>
      </DragDropContext>
      <div className="d-flex align-items-center" style={{ marginLeft: '24px' }}>
        <>
          <div style={{ width: 30, lineHeight: 1, pointerEvents: 'none', cursor: 'default' }}>
            {icon}
          </div>
          <AuthoringButtonConnected className="btn btn-link pl-0" onClick={addOne}>
            Add choice
          </AuthoringButtonConnected>
        </>
      </div>
    </>
  );
};
