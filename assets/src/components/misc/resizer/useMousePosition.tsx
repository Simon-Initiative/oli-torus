import { Nullish } from '@testing-library/dom';
import { useState, useEffect } from 'react';

export interface MousePosition {
  x: number;
  y: number;
}

export const useMousePosition = (): Nullish<MousePosition> => {
  const [mousePosition, setMousePosition] = useState<Nullish<MousePosition>>(null);

  const updateMousePosition = (ev: MouseEvent) => {
    setMousePosition({ x: ev.clientX, y: ev.clientY });
  };

  useEffect(() => {
    window.addEventListener('mousemove', updateMousePosition);

    return () => window.removeEventListener('mousemove', updateMousePosition);
  }, []);

  return mousePosition;
};
