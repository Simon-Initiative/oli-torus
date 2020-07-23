// Method to detect browsers from:
// https://stackoverflow.com/questions/9847580/
//  how-to-detect-safari-chrome-ie-firefox-and-opera-browser
export const isFirefox = typeof ((window as any).InstallTrigger) !== 'undefined';
export const isIE = /*@cc_on!@*/false || !!(document as any).documentMode;
export const isEdge = !isIE && !!(window as any).StyleMedia;
