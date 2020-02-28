import * as React from 'react';

import * as ContentModel from 'data/content/model';

import { ImageEditor } from './editors/Image';
import { YouTubeEditor } from './editors/YouTube';
import { BlockQuoteEditor } from './editors/Blockquote';
import { LinkEditor, commandDesc as linkCmd } from './editors/Link';
import { AudioEditor } from './editors/Audio';
import { CodeEditor, CodeBlockLine } from './editors/Code';
import { assertNever } from 'utils/common';
import { EditorProps } from './editors/interfaces';
import { createToggleFormatCommand as format } from './commands';

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
    case 'a':
      return <LinkEditor {...(editorProps as EditorProps<ContentModel.Hyperlink>)} />;
    case 'audio':
      return <AudioEditor {...(editorProps as EditorProps<ContentModel.Audio>)} />;
    case 'code':
      return <CodeEditor {...(editorProps as EditorProps<ContentModel.Code>)} />;
    case 'code_line':
      return <CodeBlockLine {...(editorProps as EditorProps<ContentModel.CodeLine>)} />;
    case 'table':
    case 'tr':
    case 'td':
    case 'th':
    case 'math':
    case 'math_line':


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

export const hoverMenuCommands = [
  format('fas fa-bold', 'strong', 'Bold'),
  format('fas fa-italic', 'em', 'Italic'),
  format('fas fa-code', 'code', 'Code'),
  linkCmd,
];

