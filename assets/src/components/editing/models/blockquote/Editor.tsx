import React from 'react';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
// eslint-disable-next-line
export interface BlockQuoteProps extends EditorProps<ContentModel.Blockquote> { }

export const BlockQuoteEditor = (props: BlockQuoteProps) => {

  const { attributes, children } = props;

  return (
    <blockquote {...attributes}>
      {children}
    </blockquote>
  );
};
