import React, { useState } from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import {
  Draggable,
  DraggableStateSnapshot,
  DraggingStyle,
  NotDraggingStyle,
} from 'react-beautiful-dnd';
import { Choice, ChoiceId, RichText } from 'components/activities/types';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';

interface Props {
  canRemove: boolean;
  icon: React.ReactNode;
  index: number;

  choice: Choice;
  onEdit: (id: ChoiceId, content: RichText) => void;
  onRemove: (id: ChoiceId) => void;
}
export const ChoiceAuthoringConnected: React.FC<Props> = ({
  canRemove,
  icon,
  index,
  choice,
  onEdit,
  onRemove,
}) => {
  const [showDragIndicator, setShowDragIndicator] = useState(false);

  return (
    <Draggable draggableId={choice.id} key={choice.id} index={index}>
      {(provided, snapshot) => (
        <div
          ref={provided.innerRef}
          {...provided.draggableProps}
          onMouseOver={() => !snapshot.isDragging && setShowDragIndicator(true)}
          onMouseOut={() => setShowDragIndicator(false)}
          onDragEnd={() => setShowDragIndicator(false)}
          className="choicesAuthoring__choiceContainer"
          style={dragStyle(provided.draggableProps.style, snapshot)}
        >
          <div
            {...provided.dragHandleProps}
            onFocus={() => setShowDragIndicator(true)}
            onBlur={() => setShowDragIndicator(false)}
            className="choicesAuthoring__dragHandle material-icons"
            style={{
              opacity: showDragIndicator || snapshot.isDragging ? 1 : 0,
            }}
          >
            drag_indicator
          </div>
          <div className="choicesAuthoring__choiceIcon">{icon}</div>
          <RichTextEditorConnected
            style={{ flexGrow: 1 }}
            placeholder="Answer choice"
            text={choice.content}
            onEdit={(content) => onEdit(choice.id, content)}
          />
          {canRemove && (
            <div className="choicesAuthoring__removeButtonContainer">
              <RemoveButtonConnected onClick={() => onRemove(choice.id)} />
            </div>
          )}
        </div>
      )}
    </Draggable>
  );
};

const dragStyle = (
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
