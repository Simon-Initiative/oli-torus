import { useState, useEffect } from 'react';

export interface MousePosition {
  x: number;
  y: number;
}

export const useMousePosition = () => {
  const [mouse, setMouse] = useState<MousePosition | undefined>();

  const updateMouse = (ev: MouseEvent) => setMouse({ x: ev.clientX, y: ev.clientY });
  useEffect(() => {
    window.addEventListener('mousemove', updateMouse);
    return () => window.removeEventListener('mousemove', updateMouse);
  }, []);

  return mouse;
};
