// usePointerCapability watches the browser’s pointer/hover media queries
// so components can adapt to different input types (assets/src/hooks/
// use_pointer_capability.ts:1). On mount it:
// - Checks window.matchMedia support and seeds two state values: canHover (true
// when the device can hover with a fine pointer, e.g., mouse/trackpad) and
// isCoarsePointer (true for coarse inputs like touch).
// - Subscribes to (hover: hover) and (pointer: fine) and (pointer: coarse)
// media queries, updating the state whenever the device’s capabilities change.
// - Cleans up the listeners on unmount.
// The hook returns { canHover, isCoarsePointer }, letting callers branch
// interaction logic based on whether the user can hover precisely or is using a
// coarse/touch pointer.
import { useEffect, useState } from 'react';

const HOVER_QUERY = '(hover: hover) and (pointer: fine)';
const COARSE_QUERY = '(pointer: coarse)';

type PointerCapability = {
  canHover: boolean;
  isCoarsePointer: boolean;
};

const supportsMatchMedia = () =>
  typeof window !== 'undefined' && typeof window.matchMedia === 'function';

const getInitialState = (query: string, fallback: boolean) => {
  if (!supportsMatchMedia()) {
    return fallback;
  }
  return window.matchMedia(query).matches;
};

const addListener = (media: MediaQueryList, listener: (event: MediaQueryListEvent) => void) => {
  if (typeof media.addEventListener === 'function') {
    media.addEventListener('change', listener);
  } else {
    media.addListener(listener);
  }
};

const removeListener = (media: MediaQueryList, listener: (event: MediaQueryListEvent) => void) => {
  if (typeof media.removeEventListener === 'function') {
    media.removeEventListener('change', listener);
  } else {
    media.removeListener(listener);
  }
};

export const usePointerCapability = (): PointerCapability => {
  const [canHover, setCanHover] = useState(() => getInitialState(HOVER_QUERY, true));
  const [isCoarsePointer, setIsCoarsePointer] = useState(() =>
    getInitialState(COARSE_QUERY, false),
  );

  useEffect(() => {
    if (!supportsMatchMedia()) {
      return;
    }

    const hoverQuery = window.matchMedia(HOVER_QUERY);
    const coarseQuery = window.matchMedia(COARSE_QUERY);

    const onHoverChange = (event: MediaQueryListEvent) => setCanHover(event.matches);
    const onCoarseChange = (event: MediaQueryListEvent) => setIsCoarsePointer(event.matches);

    setCanHover(hoverQuery.matches);
    setIsCoarsePointer(coarseQuery.matches);

    addListener(hoverQuery, onHoverChange);
    addListener(coarseQuery, onCoarseChange);

    return () => {
      removeListener(hoverQuery, onHoverChange);
      removeListener(coarseQuery, onCoarseChange);
    };
  }, []);

  return { canHover, isCoarsePointer };
};
