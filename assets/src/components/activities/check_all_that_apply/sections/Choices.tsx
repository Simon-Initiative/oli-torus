import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { ChoiceId, RichText } from '../../types';
import { CloseButton } from 'components/misc/CloseButton';
import { ProjectSlug } from 'data/types';
import { isCorrectChoice } from '../utils';

interface Props extends ModelEditorProps {
  onAddChoice: () => void;
  onEditChoiceContent: (id: string, content: RichText) => void;
  onToggleChoiceCorrectness: (choiceId: ChoiceId) => void;
  onRemoveChoice: (id: string) => void;
  projectSlug: ProjectSlug;
}
export const Choices = (props: Props) => {
  const {
    onAddChoice,
    onEditChoiceContent,
    onRemoveChoice,
    onToggleChoiceCorrectness,
    editMode,
    model,
    projectSlug,
  } = props;

  const { choices } = model;

  return (
    <div className="my-5">
      <Heading title="Answer Choices" id="choices" />
      {choices.map((choice, index) => (
        <div key={choice.id} className="mb-3">
          <div className="d-flex align-items-center mb-2">
            <div className="material-icons mr-2">
              <button
                style={{
                  border: 'none',
                  background: 'none',
                  color: isCorrectChoice(model, choice.id) ? '#00bc8c' : '#888',
                }}
                onClick={() => onToggleChoiceCorrectness(choice.id)}
              >
                {isCorrectChoice(model, choice.id) ? 'check_circle' : 'check_circle_outline'}
              </button>
            </div>
            Choice {index + 1}
          </div>

          <div className="d-flex" style={{ flex: 1 }}>
            <RichTextEditor
              className="flex-fill"
              projectSlug={projectSlug}
              editMode={editMode}
              text={choice.content}
              onEdit={(content) => onEditChoiceContent(choice.id, content)}
            />
            {index > 0 && (
              <CloseButton
                className="pl-3 pr-1"
                onClick={() => onRemoveChoice(choice.id)}
                editMode={editMode}
              />
            )}
          </div>
        </div>
      ))}
      <button className="btn btn-sm btn-primary my-2" disabled={!editMode} onClick={onAddChoice}>
        Add answer choice
      </button>
    </div>
  );
};
