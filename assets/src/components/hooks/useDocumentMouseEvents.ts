import { useEffect } from 'react';

export const useDocumentMouseEvents = (
  active: boolean,
  onMouseDown?: (event: MouseEvent) => void,
  onMouseUp?: (event: MouseEvent) => void,
  onMouseMove?: (event: MouseEvent) => void,
) => {
  useEffect(() => {
    if (!active) return;
    const body = document.querySelector('body') as HTMLBodyElement;
    if (!body) throw new Error('body not found');
    onMouseDown && body.addEventListener('mousedown', onMouseDown);
    onMouseUp && body.addEventListener('mouseup', onMouseUp);
    onMouseMove && body.addEventListener('mousemove', onMouseMove);
    return () => {
      onMouseDown && body.removeEventListener('mousedown', onMouseDown);
      onMouseUp && body.removeEventListener('mouseup', onMouseUp);
      onMouseMove && body.removeEventListener('mousemove', onMouseMove);
    };
  }, [active, onMouseDown, onMouseMove, onMouseUp]);
};
