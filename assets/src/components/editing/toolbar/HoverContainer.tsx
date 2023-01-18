import React, { PropsWithChildren, ReactNode, useCallback, useEffect, useState } from 'react';
import { useMousedown } from 'components/misc/resizable/useMousedown';
import { positionRect } from 'data/content/utils';
import { Popover, PopoverAlign, PopoverPosition } from 'react-tiny-popover';
import { Editor } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';

const offscreenRect = { top: -5000, left: -5000 };

interface Props {
  isOpen: boolean | ((editor: Editor) => boolean);
  content: JSX.Element;
  position?: PopoverPosition;
  reposition?: boolean;
  align?: PopoverAlign;
  relativeTo?: HTMLElement | (() => HTMLElement | undefined);
  style?: React.CSSProperties;
}
export const HoverContainer = (props: PropsWithChildren<Props>) => {
  const editor = useSlate();

  const mousedown = useMousedown();
  const [position, setPosition] = useState(offscreenRect);
  const isOpen = typeof props.isOpen === 'function' ? props.isOpen(editor) : props.isOpen;

  useEffect(() => {
    if (!isOpen) setPosition(offscreenRect);
  }, [isOpen]);

  const preventMouseDown = useCallback(
    (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => e.preventDefault(),
    [],
  );

  const children = (
    !props.children || props.style ? (
      // Add a wrapping span if there are no children (so that <Popover> works) or if we have to add a style.
      <span style={{ ...props.style }}>{props.children}</span>
    ) : (
      props.children
    )
  ) as ReactNode & JSX.Element;

  return (
    <Popover
      isOpen={isOpen}
      reposition={props.reposition}
      contentLocation={(state) => {
        const childRect =
          (props.relativeTo
            ? typeof props.relativeTo === 'function'
              ? props.relativeTo()?.getBoundingClientRect()
              : props.relativeTo.getBoundingClientRect()
            : state.childRect) || state.childRect;

        if (mousedown) return position;

        const HEADER_OFFSET = 150;
        const newPosition = positionRect(
          {
            ...state,
            position: props.position || 'bottom',
            align: props.align || 'start',
            childRect,
            padding: 16,
          },
          props.reposition,
          ReactEditor.toDOMNode(editor, editor),
          HEADER_OFFSET,
        );

        // setting state in render is bad practice, but react-tiny-popover nudges the popover
        // position even if you don't want it to change.
        if (newPosition !== position) setPosition(newPosition);

        return newPosition;
      }}
      content={
        <div className="hover-container" onMouseDown={preventMouseDown}>
          {props.content}
        </div>
      }
    >
      {children}
    </Popover>
  );
};
HoverContainer.displayName = 'HoverContainer';
