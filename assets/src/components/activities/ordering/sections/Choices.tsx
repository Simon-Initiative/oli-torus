import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { ChoiceId, RichText } from '../../types';
import { CloseButton } from 'components/misc/CloseButton';
import { ProjectSlug } from 'data/types';

interface MoveButtonProps {
  choiceId: ChoiceId;
  predicate: (choiceId: ChoiceId) => boolean;
  onClick: (choiceId: ChoiceId) => void;
  icon: string;
}
const MoveButton = ({ choiceId, predicate, onClick, icon }: MoveButtonProps) => {
  if (!predicate(choiceId)) {
    return null;
  }
  return (
    <div className="material-icons" style={{ height: 12, lineHeight: '12px' }}>
      <button
        style={{ padding: 0, border: 'none', background: 'none', height: '100%' }}
        onClick={() => onClick(choiceId)}>
          {icon}
      </button>
    </div>
  );
};

interface Props extends ModelEditorProps {
  onAddChoice: () => void;
  onEditChoiceContent: (id: ChoiceId, content: RichText) => void;
  canMoveChoiceUp: (id: ChoiceId) => boolean;
  onMoveChoiceUp: (id: ChoiceId) => void;
  canMoveChoiceDown: (id: ChoiceId) => boolean;
  onMoveChoiceDown: (id: ChoiceId) => void;
  onRemoveChoice: (id: ChoiceId) => void;
  projectSlug: ProjectSlug;
}
export const Choices = (props: Props) => {
  const { onAddChoice, onEditChoiceContent, onRemoveChoice, onMoveChoiceUp, onMoveChoiceDown,
    canMoveChoiceUp, canMoveChoiceDown, editMode, model, projectSlug } = props;

  const { choices } = model;

  return (
    <div className="my-5">
      <Heading title="Answer Choices" subtitle="Arrange the answer choices to set the correct ordering." id="choices" />

      {choices.map((choice, index) =>
        <div key={choice.id} className="mb-3">
          <div style={{ marginLeft: 24 }} className="d-flex align-items-center mb-2">
            Choice {index + 1}
          </div>

          <div className="d-flex" style={{ flex: 1 }}>
            <div className="d-flex flex-column justify-content-center">
              <MoveButton
                choiceId={choice.id}
                predicate={canMoveChoiceUp}
                onClick={onMoveChoiceUp}
                icon="arrow_drop_up" />
              <MoveButton
                choiceId={choice.id}
                predicate={canMoveChoiceDown}
                onClick={onMoveChoiceDown}
                icon="arrow_drop_down" />
            </div>
            <RichTextEditor
              className="flex-fill"
              projectSlug={projectSlug}
              editMode={editMode} text={choice.content}
              onEdit={content => onEditChoiceContent(choice.id, content)} />
            {index > 0 && <CloseButton
              className="pl-3 pr-1"
              onClick={() => onRemoveChoice(choice.id)}
              editMode={editMode} />}
          </div>
        </div>)}
      <button
        className="btn btn-sm btn-primary my-2"
        disabled={!editMode}
        onClick={onAddChoice}>Add answer choice
      </button>
    </div>
  );
};
