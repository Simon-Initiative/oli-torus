import React from 'react';
import { HasParts } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import { getExplanationContent } from 'data/activities/model/explanation';
import { PreviewPanel } from './PreviewPanel';
import { PreviewRichText } from './PreviewRichText';

interface Props {
  model: HasParts;
  partId: string;
}

export const PreviewExplanationPanel: React.FC<Props> = ({ model, partId }) => {
  const content = getExplanationContent(model, partId);

  if (!content || toSimpleText(content).trim().length === 0) {
    return (
      <PreviewPanel title="Explanation">No explanation authored for this activity.</PreviewPanel>
    );
  }

  return (
    <PreviewPanel title="Explanation">
      <PreviewRichText content={content} />
    </PreviewPanel>
  );
};
