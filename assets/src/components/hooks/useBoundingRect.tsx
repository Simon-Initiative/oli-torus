import { useEffect, useState } from 'react';

function observeSize(element: HTMLElement, callback: () => void): () => void {
  const resizeObserver = new ResizeObserver(() => {
    callback();
  });
  resizeObserver.observe(element);
  return () => {
    resizeObserver.disconnect();
  };
}

export function useBoundingRect(node: HTMLElement | null) {
  const [rect, setRect] = useState<DOMRect | null>(null);

  useEffect(() => {
    if (node) {
      return observeSize(node, () => {
        setRect(node.getBoundingClientRect());
      });
    }
  }, [node]);

  return rect;
}
