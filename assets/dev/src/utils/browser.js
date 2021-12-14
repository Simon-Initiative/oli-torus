// Method to detect browsers from:
// https://stackoverflow.com/questions/9847580/
//  how-to-detect-safari-chrome-ie-firefox-and-opera-browser
export const isFirefox = typeof window.InstallTrigger !== 'undefined';
export const isIE = /*@cc_on!@*/ false || !!document.documentMode;
export const isEdge = !isIE && !!window.StyleMedia;
//# sourceMappingURL=browser.js.map