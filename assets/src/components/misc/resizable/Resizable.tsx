import { BoundingRect, Handle } from 'components/misc/resizable/types';
import { useDOMPosition } from 'components/misc/resizable/useDOMPosition';
import { useMousePosition } from 'components/misc/resizable/useMousePosition';
import { rectFromCursor, resizeHandleStyles } from 'components/misc/resizable/utils';
import React, { PropsWithChildren, useEffect, useState } from 'react';

interface Props {
  show: boolean;
  onResize: (rect: BoundingRect) => void;
}

export const Resizable = (props: PropsWithChildren<Props>) => {
  const [handle, setHandle] = useState<Handle | undefined>(undefined);
  const cursor = useMousePosition();
  const [rect, ref] = useDOMPosition();

  useEffect(() => {
    const onMouseUp = (_e: MouseEvent) => {
      if (rect && handle && cursor) props.onResize(rectFromCursor(rect, cursor, handle));
      setHandle(undefined);
    };
    window.addEventListener('mouseup', onMouseUp);
    return () => window.removeEventListener('mouseup', onMouseUp);
  }, [rect, handle, cursor]);

  const onMouseDown = React.useCallback(
    (position: Handle) => (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
      e.preventDefault();
      setHandle(position);
    },
    [],
  );

  const handleStyles = (thisHandle: Handle | 'border') => {
    if (!rect) return { top: -5000, left: -5000, width: 0, height: 0 };
    if (!cursor) return resizeHandleStyles(rect, thisHandle);
    return resizeHandleStyles(rectFromCursor(rect, cursor, handle), thisHandle);
  };

  const resizeHandle = (handle: Handle) => (
    <div
      onMouseDown={onMouseDown(handle)}
      className="resize-selection-box-handle"
      style={handleStyles(handle)}
    ></div>
  );

  return (
    <div ref={ref} style={{ position: 'relative', width: 'fit-content' }}>
      {props.children}
      {props.show && (
        <>
          <div className="resize-selection-box-border" style={handleStyles('border')} />
          {resizeHandle('s')}
          {resizeHandle('e')}
        </>
      )}
    </div>
  );
};
