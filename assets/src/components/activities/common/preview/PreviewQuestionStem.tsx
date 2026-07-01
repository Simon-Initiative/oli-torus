import React from 'react';
import { HasStem } from 'components/activities/types';
import { PreviewRichText } from './PreviewRichText';

interface Props {
  model: HasStem;
  className?: string;
}

export const PreviewQuestionStem: React.FC<Props> = ({ model, className }) => (
  <PreviewRichText
    content={model.stem.content}
    direction={model.stem.textDirection || 'auto'}
    className={className || 'text-base leading-6 text-Text-text-high'}
  />
);
