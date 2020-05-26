import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { RichText, Hint } from '../types';
import { Description } from 'components/misc/Description';
import { CloseButton } from 'components/misc/CloseButton';

interface HintsProps {
  onAddHint: () => void;
  onEditHint: (id: string, content: RichText) => void;
  onRemoveHint: (id: string) => void;
  hints: Hint[];
  editMode: boolean;
}
export const Hints = ({ onAddHint, onEditHint, onRemoveHint, hints, editMode }: HintsProps) => {

  const deerInHeadlightsHint = hints[0];
  const bottomOutHint = hints[hints.length - 1];
  const cognitiveHints = hints.slice(1, hints.length - 1);

  return (
    <div style={{ margin: '2rem 0' }}>
      <Heading title="Hints" subtitle="The best hints follow a pattern:" id="hints" />

      {/* Deer in headlights hint */}
      <RichTextEditor editMode={editMode} text={deerInHeadlightsHint.content}
        onEdit={content => onEditHint(deerInHeadlightsHint.id, content)}>
          <Description>
            "Deer in headlights" hint - restate the problem for students who are totally confused
          </Description>
      </RichTextEditor>

      {/* Cognitive hints */}
      <Description>One or more "Cognitive" hints - explain how to solve the problem</Description>
      {cognitiveHints.map((hint, index) => (
        <React.Fragment key={hint.id}>
          <RichTextEditor editMode={editMode} text={hint.content}
            onEdit={content => onEditHint(hint.id, content)}>
            <Description>
              {index > 0 && <CloseButton editMode={editMode}
                onClick={() => onRemoveHint(hint.id)} />}
              Cognitive Hint {index + 1}
            </Description>
          </RichTextEditor>
        </React.Fragment>
      ))}
      <button disabled={!editMode} onClick={onAddHint}
        className="btn btn-primary">
        Add cognitive hint
      </button>

      {/* Bottom-out hint */}
      <RichTextEditor
        editMode={editMode}
        text={bottomOutHint.content}
        onEdit={content => onEditHint(bottomOutHint.id, content)}>
        <Description>
          "Bottom out" hint - explain the answer for students who are still lost
        </Description>
      </RichTextEditor>
    </div>
  );
};
