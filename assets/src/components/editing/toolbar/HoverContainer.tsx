import React, { useCallback, useEffect, useState } from 'react';
import {
  ArrowContainer,
  ContentLocation,
  ContentLocationGetter,
  Popover,
  PopoverState,
} from 'react-tiny-popover';
import { Editor } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';

type Props = {
  isOpen: (editor: Editor) => boolean;
  showArrow?: boolean;
  children: JSX.Element;
  contentLocation?: ContentLocationGetter;
  target?: JSX.Element;
  parentRef?: React.RefObject<HTMLElement>;
};
export const HoverContainer = (props: Props) => {
  const arrowSize = 8;

  const editor = useSlate();
  // Initialize with an off-screen position to prevent flickering on first render
  const [position, setPosition] = useState({ top: -5000, left: -5000 });
  const [mousedown, setMousedown] = useState(false);

  useEffect(() => {
    const upListener = (_e: MouseEvent) => setMousedown(false);
    const downListener = (_e: MouseEvent) => setMousedown(true);
    document.addEventListener('mouseup', upListener);
    document.addEventListener('mousedown', downListener);

    return () => {
      document.removeEventListener('mouseup', upListener);
      document.removeEventListener('mousedown', downListener);
    };
  }, []);

  const preventMouseDown = useCallback(
    (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => e.preventDefault(),
    [],
  );

  const content = (
    <div className="hovering-toolbar" onMouseDown={preventMouseDown}>
      <div className="btn-group btn-group-sm" role="group">
        {props.children}
      </div>
    </div>
  );

  const target = props.target ?? <span style={{ userSelect: 'none', display: 'none' }}></span>;

  const centerPopover = useCallback(
    (_s: PopoverState): ContentLocation => {
      if (!editor.selection || mousedown) return position;
      const node = [...Editor.nodes(editor)][1][0];
      const { top, left } = ReactEditor.toDOMNode(editor, node).getBoundingClientRect();
      const newPosition = {
        top: top + window.scrollY - 74,
        left: left + window.scrollX,
      };
      setPosition(newPosition);
      return newPosition;
    },
    [mousedown, position],
  );

  if (!props.isOpen(editor)) return target;

  return (
    <Popover
      isOpen={props.isOpen(editor)}
      align={'start'}
      padding={5}
      parentElement={props.parentRef?.current || undefined}
      content={({ childRect, popoverRect }) => {
        if (!props.showArrow) return content;
        return (
          <ArrowContainer
            position={'top'}
            childRect={childRect}
            popoverRect={popoverRect}
            arrowSize={arrowSize}
            arrowColor="rgb(38,38,37)"
            // Position the arrow in the middle of the popover
            arrowStyle={{ left: popoverRect.width / 2 - arrowSize }}
          >
            {content}
          </ArrowContainer>
        );
      }}
      contentLocation={props.contentLocation ?? centerPopover}
    >
      {target}
    </Popover>
  );
};
HoverContainer.displayName = 'HoveringToolbar';
