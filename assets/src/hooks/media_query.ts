import { useEffect, useState } from 'react';

export enum MediaSize {
  sm = '640px',
  md = '768px',
  lg = '1024px',
  xl = '1280px',
  '2xl' = '1536px',
}

function isMatch(media: MediaSize) {
  const query = `(min-width: ${media})`;
  return window.matchMedia(query).matches;
}

function findClosest(queries: MediaSize[]) {
  for (let i = queries.length - 1; i >= 0; i--) {
    if (isMatch(queries[i])) {
      return queries[i];
    }
  }
  return 'sm';
}

export const useClosestMedia = (queries: MediaSize[]) => {
  const [closest, setClosest] = useState('sm');

  useEffect(() => {
    const listener = () => setClosest(findClosest(queries));
    listener();
    window.addEventListener('resize', listener);
    return () => window.removeEventListener('resize', listener);
  }, []);

  return closest;
};

export const useMediaQuery = (screen: MediaSize) => {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const query = `(min-width: ${screen})`;
    const media = window.matchMedia(query);
    if (media.matches !== matches) {
      setMatches(media.matches);
    }
    const listener = () => setMatches(media.matches);
    window.addEventListener('resize', listener);
    return () => window.removeEventListener('resize', listener);
  }, [matches, screen]);

  return matches;
};
