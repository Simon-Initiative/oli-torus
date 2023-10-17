import React from 'react';
import { RichText } from 'components/activities/types';
import { CaptionV2, Pronunciation, TextBlock, TextDirection } from '../model/elements/types';
import { WriterContext } from './context';
import { HtmlParser } from './html';
import { ContentWriter } from './writer';

interface Props {
  content: RichText | CaptionV2 | string | TextBlock | Pronunciation;
  direction: TextDirection | undefined;
  context: WriterContext;
}
export const HtmlContentModelRenderer: React.FC<Props> = (props) => {
  // Support content persisted when RichText had a `model` property.
  const content = (props.content as any).model ? (props.content as any).model : props.content;

  const rendered = new ContentWriter().render(props.context, content, new HtmlParser());
  return <div dir={props.direction || 'ltr'}>{rendered}</div>;
};
