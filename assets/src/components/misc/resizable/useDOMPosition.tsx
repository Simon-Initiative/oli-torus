import React from 'react';

// The absolute DOM position of a ref
export const useDOMPosition = (): [DOMRect | undefined, (elem: HTMLElement | null) => void] => {
  const [rect, setRect] = React.useState<DOMRect | undefined>();
  const [elem, setElem] = React.useState<HTMLElement | undefined>();

  const updateRect = () => setRect(elem?.getBoundingClientRect());

  const ref = React.useCallback((elem: HTMLElement | null) => {
    console.log('elem changed', elem);
    if (!elem) return;
    setElem(elem);
  }, []);

  React.useEffect(() => {
    console.log('updating rect with', elem?.getBoundingClientRect());
    updateRect();

    window.addEventListener('resize', updateRect);
    window.addEventListener('scroll', updateRect);

    return () => {
      window.removeEventListener('resize', updateRect);
      window.removeEventListener('scroll', updateRect);
    };
  }, [elem]);

  return [rect, ref];
};
