import { useMousedown } from 'components/misc/resizable/useMousedown';
import { positionRect } from 'data/content/utils';
import React, { PropsWithChildren, useCallback, useEffect, useState } from 'react';
import { Popover, PopoverAlign, PopoverPosition } from 'react-tiny-popover';
import { Editor } from 'slate';
import { useSlate } from 'slate-react';

const offscreenRect = { top: -5000, left: -5000 };

interface Props {
  isOpen: boolean | ((editor: Editor) => boolean);
  content: JSX.Element;
  position?: PopoverPosition;
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

  const children = <span style={{ ...props.style }}>{props.children}</span>;

  if (!isOpen) return children;

  return (
    <Popover
      isOpen
      padding={12}
      reposition={false}
      contentLocation={(state) => {
        // Setting state in render is bad practice, but react-tiny-popover is
        // bugged and nudges the popover position even if you don't want
        // it to change.

        const childRect =
          (props.relativeTo
            ? typeof props.relativeTo === 'function'
              ? props.relativeTo()?.getBoundingClientRect()
              : props.relativeTo.getBoundingClientRect()
            : state.childRect) || state.childRect;

        if (mousedown) return position;

        const newPosition = positionRect({
          ...state,
          position: props.position || 'bottom',
          align: props.align || 'start',
          childRect,
        });

        if (newPosition !== position) setPosition(newPosition);
        return newPosition;
      }}
      content={
        <div className="hovering-toolbar" onMouseDown={preventMouseDown}>
          <div className="btn-group btn-group-sm" role="group">
            {props.content}
          </div>
        </div>
      }
    >
      {children}
    </Popover>
  );
};
HoverContainer.displayName = 'HoverContainer';
