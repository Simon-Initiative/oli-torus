import React from 'react';
import { RichText } from 'components/activities/types';
import { WriterContext } from './context';
import { HtmlParser } from './html';
import { ContentWriter } from './writer';

interface Props {
  content: RichText;
  context: WriterContext;
}
export const HtmlContentModelRenderer: React.FC<Props> = (props) => {
  // Support content persisted when RichText had a `model` property.
  const content = (props.content as any).model ? (props.content as any).model : props.content;

  return <>{new ContentWriter().render(props.context, content, new HtmlParser())}</>;
};
