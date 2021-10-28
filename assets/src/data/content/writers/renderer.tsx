import { RichText } from 'components/activities/types';
import React from 'react';
import { WriterContext } from './context';
import { HtmlParser } from './html';
import { ContentWriter } from './writer';

interface Props {
  text: RichText;
  context: WriterContext;
  style?: React.CSSProperties;
}
export const HtmlContentModelRenderer: React.FC<Props> = ({ text, context, style }: Props) => (
  <div style={style}>{new ContentWriter().render(context, text.model, new HtmlParser())}</div>
);
