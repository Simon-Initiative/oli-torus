export const internalLinkPrefix = '/course/link';
export const isInternalLink = (href) => href.startsWith(internalLinkPrefix);
export const isValidHref = (href) => href.startsWith('https://') ||
    href.startsWith('http://') ||
    href.startsWith('mailto://') ||
    href.startsWith('ftp://');
// Add a default protocol to the href to force links to resolve to an absolute path
export const addProtocol = (href) => (isValidHref(href) ? href : 'http://' + href);
// Helper function to turn a Page into a link url
export const toInternalLink = (p) => `${internalLinkPrefix}/${p.id}`;
// Takes a delivery oriented internal link and translates it to
// a link that will resolve at authoring time. This allows
// authors to use the 'Open Link' function and visit the linked course
// page.
export const translateDeliveryToAuthoring = (href, projectSlug) => {
    return `/authoring/project/${projectSlug}/resource/` + href.substr(href.lastIndexOf('/') + 1);
};
export const normalizeHref = (href) => addProtocol(href.trim());
//# sourceMappingURL=utils.js.map