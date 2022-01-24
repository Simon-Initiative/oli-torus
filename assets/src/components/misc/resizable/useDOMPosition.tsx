import React from 'react';

// The absolute DOM position of a ref
export const useDOMPosition = (): [DOMRect | undefined, (elem: HTMLElement | null) => void] => {
  const [rect, setRect] = React.useState<DOMRect | undefined>();
  const [elem, setElem] = React.useState<HTMLElement | undefined>();

  const updateRect = () => setRect(elem?.getBoundingClientRect());

  const resizeObserver = new ResizeObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.contentBoxSize) {
        updateRect();
      }
    });
  });

  const ref = React.useCallback((elem: HTMLElement | null) => {
    if (!elem) return;
    setElem(elem);
  }, []);

  React.useEffect(() => {
    updateRect();

    elem && resizeObserver.observe(elem);
    window.addEventListener('resize', updateRect);
    window.addEventListener('scroll', updateRect);

    return () => {
      resizeObserver.disconnect();
      window.removeEventListener('resize', updateRect);
      window.removeEventListener('scroll', updateRect);
    };
  }, [elem]);

  return [rect, ref];
};
