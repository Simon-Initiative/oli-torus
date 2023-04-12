import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';

export interface Props extends EditorProps<ContentModel.Blockquote> {}
export const BlockQuoteEditor = (props: Props) => {
  return <blockquote {...props.attributes}>{props.children}</blockquote>;
};
