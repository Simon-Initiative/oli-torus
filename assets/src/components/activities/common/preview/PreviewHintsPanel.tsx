import React from 'react';
import { Hint } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import { PreviewPanel } from './PreviewPanel';
import { PreviewRichText } from './PreviewRichText';

interface Props {
  hints: Hint[];
}

export const PreviewHintsPanel: React.FC<Props> = ({ hints }) => {
  const populatedHints = hints.filter((hint) => toSimpleText(hint.content).trim().length > 0);

  if (populatedHints.length === 0) {
    return <PreviewPanel title="Hints">No hints authored for this activity.</PreviewPanel>;
  }

  return (
    <div className="flex flex-col gap-3">
      {populatedHints.map((hint, index) => (
        <PreviewPanel key={hint.id} title={`Hint ${index + 1}`}>
          <PreviewRichText content={hint.content} direction={hint.textDirection || 'auto'} />
        </PreviewPanel>
      ))}
    </div>
  );
};
