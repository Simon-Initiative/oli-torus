import { ContentItem, ContentTypes } from 'data/content/writers/writer';
import * as React from 'react';
import { PopoverState } from 'react-tiny-popover';
import { Text } from 'slate';
import { isModelElement, MediaDisplayMode, ModelElement } from './model';
import { StructuredContent } from './resource';
import { toSimpleText } from './text';

// float_left and float_right no longer supported as options
export function displayModelToClassName(display: MediaDisplayMode | undefined) {
  switch (display) {
    case 'float_left':
    case 'float_right':
    case 'block':
      return 'd-block';
    default:
      return 'd-block';
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

export const centeredAbove = ({ popoverRect, childRect }: PopoverState, yOffset = 56) => {
  return {
    top: childRect.top + window.pageYOffset - yOffset,
    left: childRect.left + window.pageXOffset + childRect.width / 2 - popoverRect.width / 2,
  };
};

const contentBfs = (
  content: ContentTypes,
  cb: (c: ContentItem | ModelElement | Text) => any,
): void => {
  if (Array.isArray(content)) {
    return content.forEach((c: ContentItem | ModelElement) => contentBfs(c, cb));
  }

  cb(content);

  if (Array.isArray(content.children)) {
    return contentBfs(content.children, cb);
  }
};

export const elementsOfType = (content: ContentTypes, type: string): ModelElement[] => {
  const elements: ModelElement[] = [];
  contentBfs(content, (elem) => {
    if (isModelElement(elem) && elem.type === type) {
      elements.push(elem);
    }
  });
  return elements;
};
