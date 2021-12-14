import { ModelElement } from 'data/content/model/elements/types';
import React from 'react';
import { Text } from 'slate';
import { WriterContext } from './context';

export type Next = () => React.ReactElement;
type ElementWriter = (ctx: WriterContext, next: Next, text: ModelElement) => React.ReactElement;

export interface WriterImpl {
  text: (ctx: WriterContext, text: Text) => React.ReactElement;
  p: ElementWriter;
  h1: ElementWriter;
  h2: ElementWriter;
  h3: ElementWriter;
  h4: ElementWriter;
  h5: ElementWriter;
  h6: ElementWriter;
  img: ElementWriter;
  youtube: ElementWriter;
  iframe: ElementWriter;
  audio: ElementWriter;
  table: ElementWriter;
  tr: ElementWriter;
  th: ElementWriter;
  td: ElementWriter;
  ol: ElementWriter;
  ul: ElementWriter;
  li: ElementWriter;
  math: ElementWriter;
  mathLine: ElementWriter;
  code: ElementWriter;
  codeLine: ElementWriter;
  blockquote: ElementWriter;
  a: ElementWriter;
  inputRef: ElementWriter;
  popup: (
    ctx: WriterContext,
    anchorNext: Next,
    contentNext: Next,
    text: ModelElement,
  ) => React.ReactElement;
  unsupported: (ctx: WriterContext, element: ModelElement) => React.ReactElement;
}

export type ContentItem = { type: 'content'; children: ModelElement[] };
export function isContentItem(value: any): value is ContentItem {
  return value && value.type === 'content' && value.children !== undefined;
}

export type ContentTypes = ContentItem[] | ContentItem | ModelElement[] | ModelElement | Text;
