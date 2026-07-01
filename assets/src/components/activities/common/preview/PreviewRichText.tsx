import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { RichText } from 'components/activities/types';
import { TextDirection } from 'data/content/model/elements/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';

interface Props {
  content: RichText;
  inline?: boolean;
  className?: string;
  context?: WriterContext;
  direction?: TextDirection | 'auto';
}

export const PreviewRichText: React.FC<Props> = ({
  content,
  inline = false,
  className,
  context,
  direction = 'auto',
}) => {
  const { writerContext } = usePreviewElementContext();

  return (
    <div className={className}>
      <HtmlContentModelRenderer
        inline={inline}
        content={content}
        context={context || writerContext}
        direction={direction}
      />
    </div>
  );
};
