import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';

interface StemProps {
  stem: ActivityTypes.Stem;
}
export const Stem = ({ stem }: StemProps) => {
  return (
    <HtmlContentModelRenderer text={stem.content} />
  );
};
