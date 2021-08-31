import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { WriterContext } from 'data/content/writers/context';

interface StemProps {
  stem: ActivityTypes.Stem;
  context: WriterContext;
}

export const Stem = ({ stem, context }: StemProps) => {
  return <HtmlContentModelRenderer text={stem.content} context={context} />;
};
