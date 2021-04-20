import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { RichText, Hint } from '../types';
import { Description } from 'components/misc/Description';
import { CloseButton } from 'components/misc/CloseButton';
import { ProjectSlug } from 'data/types';

interface HintsProps {
  onAddHint: () => void;
  onEditHint: (id: string, content: RichText) => void;
  onRemoveHint: (id: string) => void;
  projectSlug: ProjectSlug;
  hints: Hint[];
  editMode: boolean;
}

export const Hints = ({
  onAddHint,
  onEditHint,
  onRemoveHint,
  hints,
  editMode,
  projectSlug,
}: HintsProps) => {
  const deerInHeadlightsHint = hints[0];
  const bottomOutHint = hints[hints.length - 1];
  const cognitiveHints = hints.slice(1, hints.length - 1);

  return (
    <div className="my-5">
      <Heading title="Hints" subtitle="The best hints follow a pattern:" id="hints" />

      {/* Deer in headlights hint */}
      <Description>
        "Deer in headlights" hint - restate the problem for students who are totally confused
      </Description>
      <RichTextEditor
        className="mb-3"
        editMode={editMode}
        text={deerInHeadlightsHint.content}
        projectSlug={projectSlug}
        onEdit={(content) => onEditHint(deerInHeadlightsHint.id, content)}
      />

      {/* Cognitive hints */}
      <div className="mb-2">
        <Description>One or more "Cognitive" hints - explain how to solve the problem</Description>
      </div>
      {cognitiveHints.map((hint, index) => (
        <React.Fragment key={hint.id}>
          <Description>
            <i className="fa fa-lightbulb text-warning mr-1"></i>Cognitive Hint {index + 1}
          </Description>
          <div className="d-flex mb-3">
            <RichTextEditor
              editMode={editMode}
              text={hint.content}
              projectSlug={projectSlug}
              onEdit={(content) => onEditHint(hint.id, content)}
            />
            {index > 0 && (
              <CloseButton
                className="pl-3 pr-1"
                onClick={() => onRemoveHint(hint.id)}
                editMode={editMode}
              />
            )}
          </div>
        </React.Fragment>
      ))}

      {/* Bottom-out hint */}
      <Description>
        "Bottom out" hint - explain the answer for students who are still lost
      </Description>
      <RichTextEditor
        className="mb-3"
        projectSlug={projectSlug}
        editMode={editMode}
        text={bottomOutHint.content}
        onEdit={(content) => onEditHint(bottomOutHint.id, content)}
      />

      <div>
        <button disabled={!editMode} onClick={onAddHint} className="btn btn-sm btn-primary">
          Add cognitive hint
        </button>
      </div>
    </div>
  );
};
