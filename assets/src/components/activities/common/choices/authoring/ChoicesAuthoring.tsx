import React from 'react';
import { Choice, makeContent, RichText } from 'components/activities/types';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import './ChoicesAuthoring.scss';
import { Draggable } from 'components/common/DraggableColumn';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';
import { toSimpleText } from 'data/content/text';

interface Props {
  icon: React.ReactNode | ((choice: Choice, index: number) => React.ReactNode);
  choices: Choice[];
  addOne: () => void;
  setAll: (choices: Choice[]) => void;
  onEdit: (id: string, content: RichText) => void;
  onRemove: (id: string) => void;
  simpleText?: boolean;
}
export const Choices: React.FC<Props> = ({
  icon,
  choices,
  addOne,
  setAll,
  onEdit,
  onRemove,
  simpleText,
}) => {
  return (
    <>
      <Draggable.Column items={choices} setItems={setAll}>
        {choices.map((choice) => (
          <Draggable.Item key={choice.id} id={choice.id} item={choice}>
            {(_choice, index) => (
              <>
                <Draggable.DragIndicator />
                <div className="choicesAuthoring__choiceIcon">
                  {typeof icon === 'function' ? icon(choice, index) : icon}
                </div>
                {simpleText ? (
                  <input
                    className="form-control"
                    placeholder="Answer choice"
                    value={toSimpleText({ children: choice.content.model })}
                    onChange={(e) => onEdit(choice.id, makeContent(e.target.value).content)}
                  />
                ) : (
                  <RichTextEditorConnected
                    style={{ flexGrow: 1, cursor: 'text' }}
                    placeholder="Answer choice"
                    text={choice.content}
                    onEdit={(content) => onEdit(choice.id, content)}
                  />
                )}

                {choices.length > 1 && (
                  <div className="choicesAuthoring__removeButtonContainer">
                    <RemoveButtonConnected onClick={() => onRemove(choice.id)} />
                  </div>
                )}
              </>
            )}
          </Draggable.Item>
        ))}
      </Draggable.Column>
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
