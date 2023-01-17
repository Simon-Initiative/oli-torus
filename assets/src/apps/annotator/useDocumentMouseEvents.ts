import { useEffect } from 'react';

export const useDocumentMouseEvents = (
  active: boolean,
  onMouseDown: (event: MouseEvent) => void,
  onMouseUp: (event: MouseEvent) => void,
  onMouseMove: (event: MouseEvent) => void,
) => {
  useEffect(() => {
    if (!active) return;
    const body = document.querySelector('body') as HTMLBodyElement;
    if (!body) throw new Error('body not found');
    body.addEventListener('mousedown', onMouseDown);
    body.addEventListener('mouseup', onMouseUp);
    body.addEventListener('mousemove', onMouseMove);
    return () => {
      body.removeEventListener('mousedown', onMouseDown);
      body.removeEventListener('mouseup', onMouseUp);
      body.removeEventListener('mousemove', onMouseMove);
    };
  }, [active, onMouseDown, onMouseMove, onMouseUp]);
};
