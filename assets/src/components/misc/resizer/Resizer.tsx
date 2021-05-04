import React, { FunctionComponent, ReactElement, useEffect, useState } from 'react';
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
  element: HTMLElement;
  constrainProportions?: boolean;
}

export const Resizer = ({ onResize, element, constrainProportions }: Props): ReactElement => {
  const [resizingFrom, setResizingFrom] = useState<Position | undefined>(undefined);
  const mousePosition = useMousePosition();

  useEffect(() => {
    const onMouseUp = (e: MouseEvent) => {
      if (element && resizingFrom) {
        const { clientX, clientY } = e;
        onResize(
          boundingRectFromMousePosition(
            clientBoundingRect(element),
            offsetBoundingRect(element),
            { x: clientX, y: clientY },
            resizingFrom,
          ),
        );
      }
      setResizingFrom(undefined);
    };

    window.addEventListener('mouseup', onMouseUp);

    return () => window.removeEventListener('mouseup', onMouseUp);
  }, [resizingFrom, element]);

  const boundResizeStyles = !element
    ? {}
    : resizeHandleStyles(
        !resizingFrom || !mousePosition
          ? offsetBoundingRect(element)
          : boundingRectFromMousePosition(
              clientBoundingRect(element),
              offsetBoundingRect(element),
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
      {!constrainProportions && (
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
