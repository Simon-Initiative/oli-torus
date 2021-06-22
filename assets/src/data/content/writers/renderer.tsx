import { ContentWriter } from './writer';
import { HtmlParser } from './html';
import { RichText } from 'components/activities/types';
import { WriterContext } from './context';
import React from 'react';

interface Props {
  text: RichText;
  context: WriterContext;
  style?: React.CSSProperties;
}
export const HtmlContentModelRenderer: React.FC<Props> = ({ text, context, style }: Props) => (
  <div
    style={style}
    dangerouslySetInnerHTML={{
      __html: new ContentWriter().render(context, text.model, new HtmlParser()),
    }}
  />
);
