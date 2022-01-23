import { BoundingRect, Handle } from 'components/misc/resizable/types';
import { useDOMPosition } from 'components/misc/resizable/useDOMPosition';
import { useMousePosition } from 'components/misc/resizable/useMousePosition';
import { boundingRect, resizeHandleStyles } from 'components/misc/resizable/utils';
import React, { PropsWithChildren, ReactElement, useEffect, useState } from 'react';

interface Props {
  onResize: (boundingRect: BoundingRect) => void;
}

export const Resizable = (props: PropsWithChildren<Props>): ReactElement => {
  const [handle, setHandle] = useState<Handle | undefined>(undefined);
  const mousePosition = useMousePosition();
  const [rect, ref] = useDOMPosition();

  console.log('rect', rect);

  useEffect(() => {
    const onMouseUp = (e: MouseEvent) => {
      if (rect && handle)
        props.onResize(boundingRect(rect, { x: e.clientX, y: e.clientY }, handle));
      // Reset the active handle to nothing
      setHandle(undefined);
    };

    window.addEventListener('mouseup', onMouseUp);

    return () => window.removeEventListener('mouseup', onMouseUp);
  }, [handle, rect]);

  // console.log('element', element, element.getBoundingClientRect());

  const onMouseDown = React.useCallback(
    (position: Handle) => (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
      e.preventDefault();
      setHandle(position);
    },
    [],
  );

  const handleStyles = (thisHandle: Handle | 'border') => {
    const currentlyResizing = handle && mousePosition;
    if (!rect) return { top: -5000, left: -5000, width: 0, height: 0 };
    if (!currentlyResizing) return resizeHandleStyles(rect, thisHandle);
    return resizeHandleStyles(boundingRect(rect, mousePosition, handle), thisHandle);
  };

  const resizeHandle = (handle: Handle) => (
    <div
      onMouseDown={onMouseDown(handle)}
      className="resize-selection-box-handle"
      style={handleStyles(handle)}
    ></div>
  );

  return (
    <>
      <div ref={ref}>{props.children}</div>
      <div className="resize-selection-box-border" style={handleStyles('border')}></div>
      {resizeHandle('s')}
      {resizeHandle('e')}
    </>
  );
};
