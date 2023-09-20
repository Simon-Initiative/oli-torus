import { useEffect, useState } from 'react';
import useWindowSize from './useWindowSize';

export function observeSize(element: HTMLElement, callback: () => void): () => void {
  const resizeObserver = new ResizeObserver(() => {
    callback();
  });
  resizeObserver.observe(element);
  return () => {
    resizeObserver.disconnect();
  };
}

type Opts = {
  triggerOnWindowResize?: boolean;
};

export function useBoundingClientRect(node: HTMLElement | null, opts?: Opts) {
  const [rect, setRect] = useState<DOMRect | null>(null);
  const windowSize = useWindowSize();

  const windowSizeTrigger = opts?.triggerOnWindowResize && windowSize;

  useEffect(() => {
    if (node) {
      return observeSize(node, () => {
        setRect(node.getBoundingClientRect());
      });
    }
  }, [node, windowSizeTrigger]);

  return rect;
}
