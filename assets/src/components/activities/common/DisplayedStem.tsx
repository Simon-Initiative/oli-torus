import * as ActivityTypes from '../types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';

interface StemProps {
  stem: ActivityTypes.Stem;
  context: WriterContext;
}

export const Stem = ({ stem, context }: StemProps) => {
  return <HtmlContentModelRenderer content={stem.content} context={context} />;
};
