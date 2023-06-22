import React from 'react';
import { RichText } from 'components/activities/types';
import { CaptionV2 } from '../model/elements/types';
import { WriterContext } from './context';
import { HtmlParser } from './html';
import { ContentWriter } from './writer';

interface Props {
  content: RichText | CaptionV2 | string;
  context: WriterContext;
}
export const HtmlContentModelRenderer: React.FC<Props> = (props) => {
  // Support content persisted when RichText had a `model` property.
  const content = (props.content as any).model ? (props.content as any).model : props.content;

  return new ContentWriter().render(props.context, content, new HtmlParser());
};
