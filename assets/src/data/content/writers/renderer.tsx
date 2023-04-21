import React from 'react';
import { RichText } from 'components/activities/types';
import { WriterContext } from './context';
import { HtmlParser } from './html';
import { ContentWriter } from './writer';

interface Props {
  content: RichText;
  context: WriterContext;
  style?: React.CSSProperties;
}
export const HtmlContentModelRenderer: React.FC<Props> = (props) => {
  // Support content persisted when RichText had a `model` property.
  const content = (props.content as any).model ? (props.content as any).model : props.content;

  return (
    <div style={props.style}>
      {new ContentWriter().render(props.context, content, new HtmlParser())}
    </div>
  );
};
