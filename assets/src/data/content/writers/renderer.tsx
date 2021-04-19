import { ContentWriter } from './writer';
import { HtmlParser } from './html';
import { RichText } from 'components/activities/types';
import { WriterContext } from './context';
import React from 'react';

interface Props {
  text: RichText;
  context: WriterContext;
}
export const HtmlContentModelRenderer = ({ text, context }: Props) =>
  <div dangerouslySetInnerHTML={{
    __html: new ContentWriter().render(context, text.model, new HtmlParser()),
  }} />;
