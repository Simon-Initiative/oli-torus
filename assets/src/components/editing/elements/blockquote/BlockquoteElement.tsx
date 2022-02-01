import React from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
export interface Props extends EditorProps<ContentModel.Blockquote> {}
export const BlockQuoteEditor = (props: Props) => {
  return <blockquote {...props.attributes}>{props.children}</blockquote>;
};
