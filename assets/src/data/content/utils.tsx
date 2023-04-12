import { StructuredContent } from './resource';
import { toSimpleText } from 'components/editing/slateUtils';
import { AllModelElements, ModelElement } from 'data/content/model/elements/types';
import { ContentItem, ContentTypes, isContentItem } from 'data/content/writers/writer';
import * as React from 'react';
import { PopoverState } from 'react-tiny-popover';
import { Element, Range, Text } from 'slate';
import { useFocused, useSelected, useSlate } from 'slate-react';

export function useElementSelected() {
  const focused = useFocused();
  const selected = useSelected();
  const [ok, setOk] = React.useState(focused && selected);
  React.useEffect(() => setOk(focused && selected), [focused, selected]);
  return ok;
}

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

  return <i>No content</i>;
}

export const positionRect = (
  { position, align, childRect, popoverRect, padding }: PopoverState,
  reposition?: boolean,
  parent?: HTMLElement | null,
  headerOffsest = 0,
): DOMRect => {
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

  // reposition to follow if scrolled off screen
  if (position === 'top' && reposition && parent) {
    // offset value to account for the header and other items at the top of the scroll view
    const topScrollOffset = headerOffsest + padding;

    const parentRect = parent.getBoundingClientRect();

    // we use childRect to determine position from left since the structured content editor
    // has wide padding (to enable proper selection from empty margin space) and we want the
    // toolbar to appear above the actual content
    left = window.scrollX + childRect.left;

    // the normal resting position of the toolbar is at the top of the slate editor
    // (adjusted for the height of the toolbar and padding)
    top = window.scrollY + parentRect.top - height - padding;

    // here we check to see if the view is scrolled past the top of the editor and if so
    // then we adjust the position the toolbar relative to the top of the window so it is
    // always in view
    const topAdjustedScrollPos = parentRect.top - topScrollOffset;
    if (topAdjustedScrollPos < 0) {
      top = top - topAdjustedScrollPos + Math.min(0, parentRect.bottom + padding - topScrollOffset);
    }
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

export const elementsOfType = (content: ContentTypes, type: string): AllModelElements[] => {
  const contentBfs = (
    content: ContentTypes,
    cb: (c: ContentItem | AllModelElements | Text) => any,
  ): void => {
    if (Array.isArray(content))
      return content.forEach((c: ContentItem | AllModelElements) => contentBfs(c, cb));

    cb(content);

    if ((isContentItem(content) || Element.isElement(content)) && Array.isArray(content.children))
      return contentBfs(content.children as Array<ModelElement>, cb);
  };

  const elements: ModelElement[] = [];
  contentBfs(
    content,
    (elem) => Element.isElement(elem) && elem.type === type && elements.push(elem),
  );
  return elements;
};

/**
 * isEmptyContent([nodes]) Returns true if the content is "empty" where "empty" is defined as:
 *   - Does not contain any text node with non-whitespace characters
 *   - Does not contain any p/header nodes with children that have non-whitespace characters recursively
 *   - Does not contain any other type of node
 */
const blocksToIgnore = ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
const shouldIgnore = (type: string) => blocksToIgnore.includes(type);
export const isEmptyContent = (content: (AllModelElements | Text)[]): boolean => {
  return !content.find(
    (c) =>
      ('text' in c && c.text.trim() !== '') || // Not empty if we have a text node with content in it
      ('type' in c && shouldIgnore(c.type) && !isEmptyContent(c.children)) || // a paragraph/heading is not empty if its children are not empty
      ('type' in c && !shouldIgnore(c.type)), // Any other non-paragraph/header element is considered not empty
  );
};
