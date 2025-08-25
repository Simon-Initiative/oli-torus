import React from 'react';
import { Choice } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';

interface Props {
  choices: Choice[];
}

export const LabelledChoices: React.FC<Props> = ({ choices }) => {
  const { projectSlug } = useAuthoringElementContext();

  const getChoiceLabel = (index: number): string => {
    return String.fromCharCode(65 + index) + '.'; // A., B., C., etc.
  };

  return (
    <div>
      {choices.map((choice, index) => (
        <div key={choice.id} className="mb-3 d-flex align-items-baseline">
          <div className="mr-2" style={{ minWidth: '20px', fontWeight: 'bold', lineHeight: '1.5' }}>
            {getChoiceLabel(index)}
          </div>
          <div style={{ flexGrow: 1 }}>
            <SlateOrMarkdownEditor
              style={{
                cursor: 'default',
                border: 'none',
                padding: 0,
                lineHeight: '1.5',
              }}
              editMode={false}
              editorType={choice.editor}
              content={choice.content}
              onEdit={() => {}} // No-op since read-only
              allowBlockElements={true}
              textDirection={choice.textDirection}
              onChangeTextDirection={() => {}} // No-op since read-only
              projectSlug={projectSlug}
            />
          </div>
        </div>
      ))}
    </div>
  );
};