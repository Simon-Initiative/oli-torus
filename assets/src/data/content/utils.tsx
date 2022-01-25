import { toSimpleText } from 'components/editing/utils';
import { ModelElement } from 'data/content/model/elements/types';
import { ContentItem, ContentTypes, isContentItem } from 'data/content/writers/writer';
import * as React from 'react';
import { PopoverState } from 'react-tiny-popover';
import { Element, Range, Text } from 'slate';
import { useFocused, useSelected, useSlate } from 'slate-react';
import { StructuredContent } from './resource';

export const useElementSelected = () => {
  const focused = useFocused();
  const selected = useSelected();
  const [ok, setOk] = React.useState(focused && selected);
  React.useEffect(() => setOk(focused && selected), [focused, selected]);
  return ok;
};

export const useCollapsedSelection = () => {
  const editor = useSlate();
  const selected = useElementSelected();
  const p = () => !!editor.selection && Range.isCollapsed(editor.selection);
  const [ok, setOk] = React.useState(selected && p());
  React.useEffect(() => setOk(selected && p()), [selected, editor.selection]);
  return ok;
};

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

export const positionRect = ({
  position,
  childRect,
  popoverRect,
  padding,
  align,
}: PopoverState): DOMRect => {
  const targetMidX = childRect.left + childRect.width / 2;
  const targetMidY = childRect.top + childRect.height / 2;
  const { width, height } = popoverRect;
  let top = window.scrollY;
  let left = window.scrollX;

  switch (position) {
    case 'left':
      left += childRect.left - padding - width;
      if (align === 'center' || !align) top += targetMidY - height / 2;
      if (align === 'start') top += childRect.top;
      if (align === 'end') top += childRect.bottom - height;
      break;
    case 'bottom':
      top += childRect.bottom + padding;
      if (align === 'center' || !align) left += targetMidX - width / 2;
      if (align === 'start') left += childRect.left;
      if (align === 'end') left += childRect.right - width;
      break;
    case 'right':
      left += childRect.right + padding;
      if (align === 'center' || !align) top += targetMidY - height / 2;
      if (align === 'start') top += childRect.top;
      if (align === 'end') top += childRect.bottom - height;
      break;
    case 'top':
    default:
      top += childRect.top - height - padding;
      if (align === 'center' || !align) left += targetMidX - width / 2;
      if (align === 'start') left += childRect.left;
      if (align === 'end') left += childRect.right - width;
      break;
  }

  return {
    top,
    y: top,
    left,
    x: left,
    width,
    height,
    right: left + width,
    bottom: top + height,
    toJSON: () => {},
  };
};

export const elementsOfType = (content: ContentTypes, type: string): ModelElement[] => {
  const contentBfs = (
    content: ContentTypes,
    cb: (c: ContentItem | ModelElement | Text) => any,
  ): void => {
    if (Array.isArray(content))
      return content.forEach((c: ContentItem | ModelElement) => contentBfs(c, cb));

    cb(content);

    if ((isContentItem(content) || Element.isElement(content)) && Array.isArray(content.children))
      return contentBfs(
        (content.children as Array<ModelElement>).filter(
          (c: ModelElement) => c.type !== 'input_ref',
        ),
        cb,
      );
  };

  const elements: ModelElement[] = [];
  contentBfs(
    content,
    (elem) => Element.isElement(elem) && elem.type === type && elements.push(elem),
  );
  return elements;
};
