import * as React from 'react';

import * as ContentModel from 'data/content/model';
import { Editor } from 'slate';
import * as Commands from './commands';
import { ImageEditor } from './editors/Image';
import { YouTubeEditor } from './editors/YouTube';
import { BlockQuoteEditor } from './editors/Blockquote';
import { assertNever } from 'utils/common';
import { EditorProps } from './editors/interfaces';

export function editorFor(
  element: ContentModel.ModelElement, props: any, editor: any): JSX.Element {

  const { attributes, children } = props;

  const editorProps = {
    model: element,
    editor,
    attributes,
    children,
  };

  switch (element.type) {
    case 'p':
      return <p {...attributes}>{children}</p>;
    case 'h1':
      return <h1 {...attributes}>{children}</h1>;
    case 'h2':
      return <h2 {...attributes}>{children}</h2>;
    case 'h3':
      return <h3 {...attributes}>{children}</h3>;
    case 'h4':
      return <h4 {...attributes}>{children}</h4>;
    case 'h5':
      return <h5 {...attributes}>{children}</h5>;
    case 'h6':
      return <h6 {...attributes}>{children}</h6>;
    case 'img':
      return <ImageEditor {...(editorProps as EditorProps<ContentModel.Image>)} />;
    case 'ol':
      return <ol {...attributes}>{children}</ol>;
    case 'ul':
      return <ul {...attributes}>{children}</ul>;
    case 'li':
      return <li {...attributes}>{children}</li>;
    case 'blockquote':
      return <BlockQuoteEditor {...(editorProps as EditorProps<ContentModel.Blockquote>)} />;
    case 'youtube':
      return <YouTubeEditor {...(editorProps as EditorProps<ContentModel.YouTube>)} />;
    case 'code':
    case 'audio':
    case 'table':
    case 'tr':
    case 'td':
    case 'th':
    case 'math':
    case 'math_line':
    case 'code_line':

    case 'a':
      return <span {...attributes}>Not implemented</span>;
    default:
      assertNever(element);
  }
}

export function markFor(mark: ContentModel.Mark, children: any): JSX.Element {
  switch (mark) {
    case 'em':
      return <em>{children}</em>;
    case 'strong':
      return <strong>{children}</strong>;
    case 'del':
      return <del>{children}</del>;
    case 'mark':
      return <mark>{children}</mark>;
    case 'code':
      return <code>{children}</code>;
    case 'var':
      return <var>{children}</var>;
    case 'sub':
      return <sub>{children}</sub>;
    case 'sup':
      return <sup>{children}</sup>;
    default:
      assertNever(mark);
  }
}

export const hoverMenuButtons = [
  { icon: 'fas fa-bold', command: (e: Editor) => Commands.toggleMark(e, 'strong') },
  { icon: 'fas fa-italic', command: (e: Editor) => Commands.toggleMark(e, 'em') },
  { icon: 'fas fa-code', command: (e: Editor) => Commands.toggleMark(e, 'code') },
];

