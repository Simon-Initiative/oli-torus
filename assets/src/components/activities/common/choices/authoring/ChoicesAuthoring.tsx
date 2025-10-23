import React from 'react';
import { Descendant } from 'slate';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { Choice, makeContent } from 'components/activities/types';
import { Draggable } from 'components/common/DraggableColumn';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { toSimpleText } from 'components/editing/slateUtils';
import { TextDirection } from 'data/content/model/elements/types';
import { DEFAULT_EDITOR, EditorType } from 'data/content/resource';
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
  onChangeEditorType?: (id: string, editorType: EditorType) => void;
  onChangeEditorTextDirection?: (id: string, textDirection: TextDirection) => void;
  onRemove: (id: string) => void;
  simpleText?: boolean;
  colorMap?: Map<string, string>;
}
export const Choices: React.FC<Props> = ({
  icon,
  choices,
  addOne,
  setAll,
  onEdit,
  onRemove,
  simpleText,
  colorMap,
  onChangeEditorType,
  onChangeEditorTextDirection,
}) => {
  const { projectSlug, editMode, mode } = useAuthoringElementContext();
  const isInstructorPreview = mode === 'instructor_preview';

  return (
    <>
      <table className="border-0">
        <tr className="border-0">
          <th></th>
          {'frequency' in choices[0] && <th className="flex justify-center">Responses</th>}
        </tr>
        <tbody>
          <tr className="border-0">
            <td className="border-0">
              <Draggable.Column items={choices} setItems={setAll}>
                {choices.map((choice) => (
                  <Draggable.Item
                    key={choice.id}
                    id={choice.id}
                    className="mb-4"
                    item={choice}
                    color={colorMap?.get(choice.id)}
                  >
                    {(choice, index) => (
                      <>
                        {!isInstructorPreview && <Draggable.DragIndicator />}
                        {renderChoiceIcon(icon, choice, index)}
                        {simpleText ? (
                          <input
                            className="form-control border-none"
                            placeholder="Answer choice"
                            value={toSimpleText(choice.content)}
                            onChange={(e) => onEdit(choice.id, makeContent(e.target.value).content)}
                          />
                        ) : (
                          <SlateOrMarkdownEditor
                            style={{
                              flexGrow: 1,
                              cursor: isInstructorPreview ? 'default' : 'text',
                              backgroundColor: colorMap?.get(choice.id),
                            }}
                            editMode={editMode && !isInstructorPreview}
                            editorType={choice.editor || DEFAULT_EDITOR}
                            placeholder="Answer choice"
                            content={choice.content}
                            onEdit={(content) => onEdit(choice.id, content)}
                            allowBlockElements={true}
                            onEditorTypeChange={(editor) =>
                              onChangeEditorType && onChangeEditorType(choice.id, editor)
                            }
                            textDirection={choice.textDirection}
                            onChangeTextDirection={(dir) =>
                              onChangeEditorTextDirection &&
                              onChangeEditorTextDirection(choice.id, dir)
                            }
                            projectSlug={projectSlug}
                          />
                        )}
                        {choices.length > 1 && !isInstructorPreview && (
                          <div className={styles.removeButtonContainer}>
                            <RemoveButtonConnected onClick={() => onRemove(choice.id)} />
                          </div>
                        )}
                      </>
                    )}
                  </Draggable.Item>
                ))}
              </Draggable.Column>
            </td>
            {'frequency' in choices[0] && (
              <td className="flex justify-center border-0">
                <div>
                  {choices.map((choice) => (
                    <div className="mb-4 ml-4 px-4 h-[41px] flex items-center" key={choice.id}>
                      {choice.frequency || 0}
                    </div>
                  ))}
                </div>
              </td>
            )}
          </tr>
        </tbody>
      </table>
      {!isInstructorPreview && <AddChoiceButton icon={icon} addOne={addOne} />}
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
