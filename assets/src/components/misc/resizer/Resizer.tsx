import React, { PropsWithChildren, ReactElement, useEffect, useState } from 'react';
import { useMousePosition } from 'components/misc/resizer/useMousePosition';
import {
  boundingRectFromMousePosition,
  clientBoundingRect,
  offsetBoundingRect,
  resizeHandleStyles,
} from 'components/misc/resizer/utils';
import { BoundingRect, Position } from 'components/misc/resizer/types';

interface Props {
  onResize: (boundingRect: BoundingRect) => void;
  displayRef: React.RefObject<HTMLElement>;
  allowDistortion?: boolean;
}

export const Resizer = ({
  onResize,
  displayRef,
  allowDistortion,
}: PropsWithChildren<Props>): ReactElement => {
  const [resizingFrom, setResizingFrom] = useState<Position | undefined>(undefined);

  const onMouseUp = (e: MouseEvent) => {
    if (displayRef.current && resizingFrom) {
      const { clientX, clientY } = e;
      onResize(
        boundingRectFromMousePosition(
          clientBoundingRect(displayRef.current),
          offsetBoundingRect(displayRef.current),
          { x: clientX, y: clientY },
          resizingFrom,
        ),
      );
    }
    setResizingFrom(undefined);
  };

  useEffect(() => {
    window.addEventListener('mouseup', onMouseUp);

    return () => window.removeEventListener('mouseup', onMouseUp);
  }, [resizingFrom, displayRef.current]);

  const mousePosition = useMousePosition();

  const boundResizeStyles = !displayRef.current
    ? {}
    : resizeHandleStyles(
        !resizingFrom || !mousePosition
          ? offsetBoundingRect(displayRef.current)
          : boundingRectFromMousePosition(
              clientBoundingRect(displayRef.current),
              offsetBoundingRect(displayRef.current),
              mousePosition,
              resizingFrom,
            ),
      );

  const onMouseDown = (position: Position) => (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
    e.preventDefault();
    setResizingFrom(position);
  };

  const resizeHandle = (position: Position) => (
    <div
      onMouseDown={onMouseDown(position)}
      className="resize-selection-box-handle"
      style={boundResizeStyles(position)}
    ></div>
  );

  return (
    <div>
      <div className="resize-selection-box-border" style={boundResizeStyles('border')}></div>
      {resizeHandle('nw')}
      {resizeHandle('ne')}
      {resizeHandle('sw')}
      {resizeHandle('se')}
      {allowDistortion && (
        <>
          {resizeHandle('n')}
          {resizeHandle('s')}
          {resizeHandle('e')}
          {resizeHandle('w')}
        </>
      )}
    </div>
  );
};
