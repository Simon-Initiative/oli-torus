import React from 'react';
import { Choice } from 'components/activities/types';
import { PreviewRichText } from './PreviewRichText';

interface Props {
  choices: Choice[];
  surface?: 'card' | 'plain';
}

const GripDots: React.FC = () => (
  <div className="grid shrink-0 grid-cols-2 gap-1 pt-1 text-Text-text-low" aria-hidden="true">
    {Array.from({ length: 6 }).map((_, index) => (
      <span key={index} className="h-1.5 w-1.5 rounded-full bg-current" />
    ))}
  </div>
);

export const PreviewOrderedChoiceList: React.FC<Props> = ({ choices, surface = 'card' }) => {
  const itemClassName =
    surface === 'plain'
      ? 'flex items-start gap-3 rounded-md border border-Border-border-default bg-Surface-surface-primary p-3'
      : 'flex items-start gap-3 rounded-md border border-Border-border-default bg-Surface-surface-primary p-3';

  return (
    <div className="flex flex-col gap-2">
      {choices.map((choice, index) => (
        <div key={choice.id} className={itemClassName}>
          <GripDots />
          <div className="min-w-0 flex-1">
            <span className="mr-2 text-base leading-7 text-Text-text-high">{`${index + 1}.`}</span>
            <PreviewRichText
              content={choice.content}
              className="inline-block text-base leading-7 text-Text-text-high [&_.content_p]:my-0"
              direction={choice.textDirection || 'auto'}
            />
          </div>
        </div>
      ))}
    </div>
  );
};
