import React from 'react';
import { useSlate, ReactEditor } from 'slate-react';
import Popover, { ArrowContainer, ContentLocationGetter } from 'react-tiny-popover';

type HoveringToolbarProps = {
  isOpen: (editor: ReactEditor) => boolean;
  showArrow?: boolean;
  children: JSX.Element;
  onClickOutside?: ((e: MouseEvent) => void);
  contentLocation?: ContentLocationGetter;
  target?: JSX.Element;
};
// eslint-disable-next-line
export const HoveringToolbar = React.memo((props: HoveringToolbarProps) => {
  const editor = useSlate();

  const arrowSize = 8;

  const content = (
    <div className="hovering-toolbar">
      <div className="btn-group btn-group-sm" role="group">
        {props.children}
      </div>
    </div>
  );

  return (
    <Popover
      isOpen={props.isOpen(editor)}
      align={'center'}
      position="top"
      onClickOutside={props.onClickOutside}
      content={({ position, targetRect, popoverRect }) => {
        if (props.showArrow) {
          return (
            <ArrowContainer
              position={position}
              targetRect={targetRect}
              popoverRect={popoverRect}
              arrowSize={arrowSize}
              arrowColor="rgb(38,38,37)"
              // Position the arrow in the middle of the popover
              arrowStyle={{ left: popoverRect.width / 2 - arrowSize }}>
              {content}
            </ArrowContainer>
          );
        }
        return content;
      }}
      transitionDuration={0}
      disableReposition
      contentLocation={props.contentLocation
        ? props.contentLocation
        : ({ popoverRect }) => {
          // Position the popover above the center of the selection
          const native = window.getSelection();
          if (!native) return { top: 0, left: 0 };
          const range = native.getRangeAt(0);
          const selectionRect = range.getBoundingClientRect();

          return {
            top: selectionRect.top + window.pageYOffset - 50,
            left: selectionRect.left + window.pageXOffset
              + selectionRect.width / 2 - popoverRect.width / 2,
          };
        }}
    >
      {props.target || <span style={{ userSelect: 'none', display: 'none' }}></span>}
    </Popover>
  );
});
