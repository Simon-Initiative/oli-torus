// Method to detect browsers from:
// https://stackoverflow.com/questions/9847580/
//  how-to-detect-safari-chrome-ie-firefox-and-opera-browser
export const isFirefox = typeof (window as any).InstallTrigger !== 'undefined';
export const isIE = /*@cc_on!@*/ false || !!(document as any).documentMode;
export const isEdge = !isIE && !!(window as any).StyleMedia;

export const isDarkMode = () =>
  window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;

export const addDarkModeListener = (fn: (mode: 'light' | 'dark') => void) => {
  const listener = (event: any) => {
    event.matches ? fn('dark') : fn('light');
  };
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', listener);

  return listener;
};

export const removeDarkModeListener = (listener: EventListener) =>
  window.matchMedia('(prefers-color-scheme: dark)').removeEventListener('change', listener);
