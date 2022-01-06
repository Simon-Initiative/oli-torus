import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ArrowContainer,
  ContentLocation,
  ContentLocationGetter,
  Popover,
  PopoverState,
} from 'react-tiny-popover';
import { Editor } from 'slate';
import { useSlate } from 'slate-react';

type HoveringToolbarProps = {
  isOpen: (editor: Editor) => boolean;
  showArrow?: boolean;
  children: JSX.Element;
  onClickOutside?: (e: MouseEvent) => void;
  contentLocation?: ContentLocationGetter;
  target?: JSX.Element;
  parentRef?: React.RefObject<HTMLElement>;
};
export const HoveringToolbar = React.memo((props: HoveringToolbarProps) => {
  const arrowSize = 8;

  const editor = useSlate();

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

  const content = useMemo(
    () => (
      <div className="hovering-toolbar" onMouseDown={preventMouseDown}>
        <div className="btn-group btn-group-sm" role="group">
          {props.children}
        </div>
      </div>
    ),
    [props.children],
  );

  const target = useMemo(
    () => props.target || <span style={{ userSelect: 'none', display: 'none' }}></span>,
    [props.target],
  );

  const isOpen = useMemo(() => props.isOpen(editor) && !mousedown, [editor, mousedown]);

  const centerPopover = useCallback(
    ({ popoverRect, parentRect }: PopoverState): ContentLocation => {
      // Position the popover above the center of the selection
      const native = window.getSelection();
      if (!native || mousedown) return parentRect;

      const selectionRect = native.getRangeAt(0).getBoundingClientRect();

      return {
        top: selectionRect.top + window.pageYOffset - 56,
        left:
          selectionRect.left + window.pageXOffset + selectionRect.width / 2 - popoverRect.width / 2,
      };
    },
    [mousedown],
  );

  if (!isOpen) return target;

  return (
    <Popover
      isOpen={isOpen}
      align={'center'}
      padding={5}
      parentElement={props.parentRef?.current || undefined}
      content={({ childRect, popoverRect }) => {
        if (props.showArrow) {
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
        }
        return content;
      }}
      contentLocation={props.contentLocation || centerPopover}
    >
      {target}
    </Popover>
  );
});
HoveringToolbar.displayName = 'HoveringToolbar';
