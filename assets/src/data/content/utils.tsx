import * as React from 'react';
import { StructuredContent } from './resource';
import { toSimpleText } from './text';
import { MediaDisplayMode } from './model';

const textLimit = 25;

// float_left and float_right no longer supported as options
export function displayModelToClassName(display: MediaDisplayMode | undefined) {
  switch (display) {
    case 'float_left':
    case 'float_right':
    case 'block': return 'd-block';
    default: return 'd-block';
  }
}

export function getContentDescription(content: StructuredContent): JSX.Element {

  let simpleText;

  if (content.children.length > 0) {

    let i = 0;

    while (i < content.children.length) {
      const item = content.children[i];

      switch (item.type) {
        case 'audio':
          return <i>Audio Clip</i>;
        case 'code':
          return <i>Code Block</i>;
        case 'img':
          return <i>Image</i>;
        case 'youtube':
          return <i>YouTube Video</i>;
        case 'table':
          return <i>Table</i>;
        case 'math':
          return <i>Math Expression</i>;
        case 'ol':
        case 'ul':
          return <i>List</i>;
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
        case 'p':
        case 'blockquote':
          simpleText = toSimpleText(item).trim();
          if (simpleText !== '') {
            return <span>{simpleText}</span>;
          }
      }
      i = i + 1;

    }
  }

  return <i>Empty</i>;
}
