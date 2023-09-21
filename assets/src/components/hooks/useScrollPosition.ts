import { useEffect, useState } from 'react';
import { throttle } from 'lodash';

export function useScrollPosition(el?: HTMLElement, throttleMs = 200) {
  const [scrollPos, setScrollPos] = useState(0);

  const scrollElement: HTMLElement = el || (document.documentElement as HTMLElement);

  useEffect(() => {
    const scrollListener = throttle(() => setScrollPos(scrollElement.scrollTop), throttleMs);
    document.addEventListener('scroll', scrollListener);

    return () => {
      window.removeEventListener('scroll', scrollListener);
    };
  }, [scrollPos]);

  return scrollPos;
}
