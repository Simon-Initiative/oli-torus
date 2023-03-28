import { useEffect, useRef } from 'react';

/**
 * Attaches a click handler to the window that is triggered when
 * clicked outside the ref element. Optimization is recommended to
 * wrap the handler function in useCallback to prevent listeners
 * from be created/destroyed on every render.
 *
 * @param ref
 * @param handler
 */
export const useOnClickOutside = <T>(handler: (e: MouseEvent) => void) => {
  const ref = useRef<T>(null);

  useEffect(() => {
    const listener = (event: MouseEvent) => {
      // Do nothing if clicking ref's element or descendent elements
      if (!ref.current || (ref.current as any).contains(event.target)) {
        return;
      }
      handler(event);
    };
    window.addEventListener('click', listener);

    return () => {
      window.removeEventListener('click', listener);
    };
  }, [ref, handler]);

  return ref;
};
