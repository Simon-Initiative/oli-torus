import React, { useState } from 'react';
import { AuthoringButton } from 'components/misc/AuthoringButton';
import { DragDropContext, Droppable } from 'react-beautiful-dnd';
import { Choice } from 'components/activities/types';

interface Props {
  icon: React.ReactNode;

  choices: Choice[];
  addOne: () => void;
  setAll: (choices: Choice[]) => void;
}
export const ChoicesAuthoring: React.FC<Props> = ({ icon, choices, addOne, setAll }) => {
  return (
    <>
      <DragDropContext
        onDragEnd={({ destination, source }) => {
          if (!destination) {
            return;
          }
          if (
            destination.droppableId === source.droppableId &&
            destination.index === source.index
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
                <Choice.Authoring.Connected
                  icon={icon}
                  key={index + 'choice'}
                  index={index}
                  choice={choice}
                  canRemove={choices.length > 1}
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
          <AuthoringButton className="btn btn-link pl-2" onClick={addOne}>
            Add choice
          </AuthoringButton>
        </>
      </div>
    </>
  );
};
