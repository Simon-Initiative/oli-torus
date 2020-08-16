export const internalLinkPrefix = '/course/link';

export const isInternalLink = (href: string) => href.startsWith(internalLinkPrefix);

export const isValidHref = (href: string) => href.startsWith('https://')
  || href.startsWith('http://')
  || href.startsWith('mailto://')
  || href.startsWith('ftp://');

export const addProtocol = (href: string) => isValidHref(href)
  ? href
  : 'http://' + href;

// Takes a delivery oriented internal link and translates it to
// a link that will resolve at authoring time. This allows
// authors to use the 'Open Link' function and visit the linked course
// page.
export const translateDeliveryToAuthoring = (href: string, projectSlug: string) => {
  return `/project/${projectSlug}/resource/` + href.substr(href.lastIndexOf('/') + 1);
};

export const normalizeHref = (href: string) => addProtocol(href.trim());
