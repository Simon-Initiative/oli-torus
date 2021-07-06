import React from 'react';
import { DragDropContext, Droppable } from 'react-beautiful-dnd';
import { Choice, RichText } from 'components/activities/types';
import { ChoiceAuthoringConnected } from 'components/activities/common/choices/authoring/ChoiceAuthoring';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import './ChoicesAuthoring.scss';

interface Props {
  icon: React.ReactNode | ((choice: Choice, index: number) => React.ReactNode);
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
            <div
              {...provided.droppableProps}
              ref={provided.innerRef}
              className="choicesAuthoring__choicesContainer"
            >
              {choices.map((choice, index) => (
                <ChoiceAuthoringConnected
                  icon={typeof icon === 'function' ? icon(choice, index) : icon}
                  key={'choice-' + index}
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
      <AddChoiceButton icon={icon} addOne={addOne} />
    </>
  );
};

interface AddChoiceButtonProps {
  icon: Props['icon'];
  addOne: Props['addOne'];
}
const AddChoiceButton: React.FC<AddChoiceButtonProps> = ({ icon, addOne }) => {
  return (
    <div className="choicesAuthoring__addChoiceContainer">
      <div className="choicesAuthoring__choiceIcon">{icon}</div>
      <AuthoringButtonConnected className="choicesAuthoring__addChoiceButton" action={addOne}>
        Add choice
      </AuthoringButtonConnected>
    </div>
  );
};
