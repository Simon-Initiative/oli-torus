import { ServerError } from 'data/persistence/common';
import * as Persistence from 'data/persistence/resource';

export type LinkablePages =
  | {
      type: 'Uninitialized';
    }
  | {
      type: 'Waiting';
    }
  | Persistence.PagesReceived
  | ServerError;

export const internalLinkPrefix = '/course/link';

export const isInternalLink = (href: string) => href.startsWith(internalLinkPrefix);

export const isValidHref = (href: string) =>
  href.startsWith('https://') ||
  href.startsWith('http://') ||
  href.startsWith('mailto://') ||
  href.startsWith('ftp://');

// Add a default protocol to the href to force links to resolve to an absolute path
export const addProtocol = (href: string) => (isValidHref(href) ? href : 'http://' + href);

// Helper function to turn a Page into a link url
export const toInternalLink = (p: any) => `${internalLinkPrefix}/${p.id}`;

// Takes a delivery oriented internal link and translates it to
// a link that will resolve at authoring time. This allows
// authors to use the 'Open Link' function and visit the linked course
// page.
export const translateDeliveryToAuthoring = (href: string, projectSlug: string) => {
  return `/authoring/project/${projectSlug}/resource/` + href.substr(href.lastIndexOf('/') + 1);
};

export const normalizeHref = (href: string) => addProtocol(href.trim());
