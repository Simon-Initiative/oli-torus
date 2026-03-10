const INTERNAL_COURSE_LINK_PREFIX = '/course/link/';

const extractPageSlug = (href: string): { pageSlug: string; suffix: string } | null => {
  if (!href.startsWith(INTERNAL_COURSE_LINK_PREFIX)) {
    return null;
  }

  const withoutPrefix = href.slice(INTERNAL_COURSE_LINK_PREFIX.length);
  const pageSlug = withoutPrefix.split(/[?#]/)[0];

  if (!pageSlug) {
    return null;
  }

  return {
    pageSlug,
    suffix: withoutPrefix.slice(pageSlug.length),
  };
};

const resolveContextPath = (): string => {
  if (typeof window === 'undefined') {
    return '';
  }

  return window.location.pathname;
};

export const resolveAdaptiveIframeSource = (href?: string, pathname?: string): string => {
  if (!href) {
    return '';
  }

  const extracted = extractPageSlug(href);
  if (!extracted) {
    return href;
  }

  const { pageSlug, suffix } = extracted;
  const path = pathname ?? resolveContextPath();
  if (!path) {
    return href;
  }

  const authorPreviewMatch = path.match(/^\/authoring\/project\/([^/]+)\/preview\/[^/]+/);
  if (authorPreviewMatch?.[1]) {
    return `/authoring/project/${authorPreviewMatch[1]}/preview/${pageSlug}${suffix}`;
  }

  const authorResourceMatch = path.match(/^\/authoring\/project\/([^/]+)\/resource\/[^/]+/);
  if (authorResourceMatch?.[1]) {
    return `/authoring/project/${authorResourceMatch[1]}/preview/${pageSlug}${suffix}`;
  }

  const workspaceAuthorMatch = path.match(
    /^\/workspaces\/course_author\/([^/]+)\/curriculum\/[^/]+\/edit/,
  );
  if (workspaceAuthorMatch?.[1]) {
    return `/authoring/project/${workspaceAuthorMatch[1]}/preview/${pageSlug}${suffix}`;
  }

  const instructorPreviewMatch = path.match(/^\/sections\/([^/]+)\/preview\/page\/[^/]+/);
  if (instructorPreviewMatch?.[1]) {
    return `/sections/${instructorPreviewMatch[1]}/preview/page/${pageSlug}${suffix}`;
  }

  const sectionMatch = path.match(/^\/sections\/([^/]+)/);
  if (sectionMatch?.[1]) {
    return `/sections/${sectionMatch[1]}/lesson/${pageSlug}${suffix}`;
  }

  return href;
};
