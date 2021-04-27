import { useState, useEffect } from 'react';

export interface MousePosition {
  x: number | null;
  y: number | null;
}

export const useMousePosition = () => {
  const [mousePosition, setMousePosition] = useState<MousePosition>({
    x: null,
    y: null,
  });

  const updateMousePosition = (ev: MouseEvent) => {
    // console.log(ev.clientX, ev.clientY);
    setMousePosition({ x: ev.clientX, y: ev.clientY });
  };

  useEffect(() => {
    window.addEventListener('mousemove', updateMousePosition);

    return () => window.removeEventListener('mousemove', updateMousePosition);
  }, []);

  return mousePosition;
};
