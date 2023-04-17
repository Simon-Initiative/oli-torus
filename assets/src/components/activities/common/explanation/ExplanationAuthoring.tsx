import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts, RichText } from 'components/activities/types';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { getExplanationContent, setExplanationContent } from 'data/activities/model/explanation';

interface Props {
  partId: string;
}
export const Explanation: React.FC<Props> = (props) => {
  const { dispatch, model } = useAuthoringElementContext<HasParts>();
  return (
    <RichTextEditorConnected
      placeholder="Explanation"
      value={getExplanationContent(model, props.partId)}
      onEdit={(content: RichText) => dispatch(setExplanationContent(props.partId, content))}
    />
  );
};
