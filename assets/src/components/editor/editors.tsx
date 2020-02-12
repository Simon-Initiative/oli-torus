import * as React from 'react';

import { ModelElement, Mark } from './model';
import { Editor } from 'slate'
import * as Commands from './commands';
import { ImageEditor } from './editors/Image';

function assertNever(x: never): never {
  throw new Error("Unexpected object: " + x);
}

export function editorFor(element: ModelElement, props: any, editor: any): JSX.Element {
  switch (element.type) {
    case 'p':
      return <p {...props.attributes}>{props.children}</p>;
    case 'h1':
      return <h1 {...props.attributes}>{props.children}</h1>;
    case 'h2':
      return <h2 {...props.attributes}>{props.children}</h2>;
    case 'h3':
      return <h3 {...props.attributes}>{props.children}</h3>;
    case 'h4':
      return <h4 {...props.attributes}>{props.children}</h4>;
    case 'h5':
      return <h5 {...props.attributes}>{props.children}</h5>;
    case 'h6':
      return <h6 {...props.attributes}>{props.children}</h6>;
    case 'img':
      return <ImageEditor editor={editor} attributes={props.attributes} element={element} isFocused={false} isSelected={false} />;
    case 'code':
    case 'youtube':
    case 'audio':
    case 'img':
    case 'table':
    case 'tr':
    case 'thead':
    case 'tbody':
    case 'tfoot':
    case 'td':
    case 'th':
    case 'ol':
    case 'ul':
    case 'li':
    case 'math':
    case 'math_line':
    case 'code_line':
    case 'blockquote':
    case 'example':
    case 'a':
    case 'dfn':
    case 'cite':
      return <span {...props.attributes}>Not implemented</span>;
    default:
      assertNever(element);
  }
}

export function markFor(mark: Mark, children: any): JSX.Element {
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
  { icon: 'fas fa-code', command: (e: Editor) => Commands.toggleMark(e, 'code') }
];

