import React from 'react';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import * as ActivityTypes from '../types';

interface StemProps {
  stem: ActivityTypes.Stem;
  context: WriterContext;
}

export const Stem = ({ stem, context }: StemProps) => {
  return <HtmlContentModelRenderer content={stem.content} context={context} />;
};
