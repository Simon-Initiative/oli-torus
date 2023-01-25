import React from 'react';
import { Choice, makeContent } from 'components/activities/types';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { Draggable } from 'components/common/DraggableColumn';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { toSimpleText } from 'components/editing/slateUtils';
import { Descendant } from 'slate';
import { classNames } from 'utils/classNames';

import styles from './ChoicesAuthoring.modules.scss';

const renderChoiceIcon = (icon: any, choice: any, index: any) =>
  icon ? (
    typeof icon === 'function' ? (
      <div className={styles.choiceIcon}>{icon(choice, index)}</div>
    ) : (
      <div className={styles.choiceIcon}>{icon}</div>
    )
  ) : undefined;

interface Props {
  icon?: React.ReactNode | ((choice: Choice, index: number) => React.ReactNode);
  choices: Choice[];
  addOne: () => void;
  setAll: (choices: Choice[]) => void;
  onEdit: (id: string, content: Descendant[]) => void;
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
          <Draggable.Item key={choice.id} id={choice.id} className="mb-4" item={choice}>
            {(_choice, index) => (
              <>
                <Draggable.DragIndicator />
                {renderChoiceIcon(icon, choice, index)}
                {simpleText ? (
                  <input
                    className="form-control"
                    placeholder="Answer choice"
                    value={toSimpleText(choice.content)}
                    onChange={(e) => onEdit(choice.id, makeContent(e.target.value).content)}
                  />
                ) : (
                  <RichTextEditorConnected
                    style={{ flexGrow: 1, cursor: 'text' }}
                    placeholder="Answer choice"
                    value={choice.content}
                    onEdit={(content) => onEdit(choice.id, content)}
                  />
                )}

                {choices.length > 1 && (
                  <div className={styles.removeButtonContainer}>
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
const AddChoiceButton: React.FC<AddChoiceButtonProps> = ({ addOne }) => {
  return (
    <div className={styles.addChoiceContainer}>
      <AuthoringButtonConnected
        className={classNames(styles.AddChoiceButton, 'btn btn-link pl-0')}
        action={addOne}
      >
        Add choice
      </AuthoringButtonConnected>
    </div>
  );
};
