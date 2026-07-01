const storageKey = 'torus.saygSavedWorkNotice';

/**
 * Coordinates the "your work has been saved" notice shown after leaving a
 * Score as You Go assignment.
 *
 * The source SAYG page writes a short-lived notice before internal navigation.
 * The destination page consumes that notice once and renders a dismissible
 * banner. sessionStorage is intentionally used so the notice is scoped to the
 * current tab and is not shown again in a future browser session.
 */
type SavedWorkNotice = {
  message: string;
  sourceUrl: string;
  targetUrl: string;
};

type ScoreAsYouGoNavigationNoticeHook = {
  el: HTMLElement;
  clickListener?: (event: MouseEvent) => void;
  pageLoadingStartListener?: (event: Event) => void;
};

type ScoreAsYouGoSavedWorkNoticeHook = {
  el: HTMLElement;
  consumeNotice?: () => void;
  cleanupSavedWorkNotice?: () => void;
};

const readNotice = (): SavedWorkNotice | null => {
  try {
    const value = window.sessionStorage.getItem(storageKey);
    if (!value) return null;

    const notice = JSON.parse(value) as SavedWorkNotice;
    return notice.message && notice.sourceUrl && notice.targetUrl ? notice : null;
  } catch {
    return null;
  }
};

const writeNotice = (message: string, targetUrl: string) => {
  try {
    window.sessionStorage.setItem(
      storageKey,
      JSON.stringify({ message, sourceUrl: window.location.href, targetUrl }),
    );
  } catch {
    // Ignore storage failures. Navigation should continue normally.
  }
};

const clearNotice = () => {
  try {
    window.sessionStorage.removeItem(storageKey);
  } catch {
    // Ignore storage failures.
  }
};

// SAYG lesson pages render this hidden marker. It lets destination pages know
// whether the current page is also a SAYG page without coupling this hook to
// LiveView assigns or route names.
const isScoreAsYouGoPage = (): boolean =>
  document.getElementById('sayg_navigation_notice_source') !== null;

const internalUrlFor = (href: string): URL | null => {
  try {
    const url = new URL(href, window.location.href);
    if (url.origin !== window.location.origin) return null;

    return url;
  } catch {
    return null;
  }
};

// Compare the current document location without the hash. Fragment-only changes
// keep the student on the same lesson page and should not trigger the notice.
const isCurrentPageUrl = (url: URL): boolean =>
  url.origin === window.location.origin &&
  url.pathname === window.location.pathname &&
  url.search === window.location.search;

// Accept the stored string form used in sessionStorage, but compare it using the
// same hash-agnostic current-page check.
const isCurrentUrl = (href: string): boolean => {
  const url = internalUrlFor(href);

  return url ? isCurrentPageUrl(url) : false;
};

const shouldShowNotice = (notice: SavedWorkNotice): boolean => {
  // Do not show the banner when returning to the same SAYG page that created it.
  if (isCurrentUrl(notice.sourceUrl)) return false;

  // Prefer the exact intended target. The non-SAYG fallback handles redirects
  // and controller-rendered pages reached from the original internal navigation.
  return isCurrentUrl(notice.targetUrl) || !isScoreAsYouGoPage();
};

const internalNavigationUrl = (event: MouseEvent, link: HTMLAnchorElement): URL | null => {
  // Only plain left-click same-tab navigation is treated as an internal exit.
  // Modified clicks, downloads, anchors, javascript URLs, and external links
  // should behave normally and should not create the saved-work banner.
  if (event.defaultPrevented) return null;
  if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
    return null;
  }

  const target = link.getAttribute('target')?.toLowerCase();
  if ((target && target !== '_self') || link.hasAttribute('download')) return null;

  const href = link.getAttribute('href');
  if (!href || href.startsWith('#') || href.startsWith('javascript:')) return null;

  const url = internalUrlFor(href);
  if (!url || isCurrentPageUrl(url)) return null;

  return url;
};

const mountSavedWorkNotice = (noticeElement: HTMLElement): (() => void) | undefined => {
  const messageTarget = noticeElement.querySelector<HTMLElement>('[data-sayg-saved-work-message]');
  const dismissButton = noticeElement.querySelector<HTMLButtonElement>(
    '[data-sayg-saved-work-dismiss]',
  );
  const notice = readNotice();

  if (!notice || !messageTarget) return;

  if (!shouldShowNotice(notice)) {
    clearNotice();
    return;
  }

  const dismissListener = () => {
    noticeElement.classList.add('hidden');
  };

  messageTarget.textContent = notice.message;
  noticeElement.classList.remove('hidden');
  noticeElement.dataset.initialized = 'true';
  clearNotice();

  dismissButton?.addEventListener('click', dismissListener);

  return () => {
    dismissButton?.removeEventListener('click', dismissListener);
  };
};

export const ScoreAsYouGoNavigationNotice = {
  mounted(this: ScoreAsYouGoNavigationNoticeHook) {
    const message = this.el.dataset.message;
    if (!message) return;

    // Capture regular link clicks from a SAYG page before navigation starts.
    this.clickListener = (event: MouseEvent) => {
      const target = event.target;
      if (!(target instanceof Element)) return;

      const link = target.closest('a[href]') as HTMLAnchorElement | null;
      if (!link) return;

      const url = internalNavigationUrl(event, link);
      if (!url) return;

      writeNotice(message, url.href);
    };

    // Capture LiveView patch/navigate events that may not originate from a
    // normal anchor click but still represent internal navigation.
    this.pageLoadingStartListener = (event: Event) => {
      const to = (event as CustomEvent<{ to?: string }>).detail?.to;
      if (!to) return;

      const url = internalUrlFor(to);
      if (!url || isCurrentPageUrl(url)) return;

      writeNotice(message, url.href);
    };

    document.addEventListener('click', this.clickListener);
    window.addEventListener('phx:page-loading-start', this.pageLoadingStartListener);
  },

  destroyed(this: ScoreAsYouGoNavigationNoticeHook) {
    if (this.clickListener) {
      document.removeEventListener('click', this.clickListener);
    }

    if (this.pageLoadingStartListener) {
      window.removeEventListener('phx:page-loading-start', this.pageLoadingStartListener);
    }
  },
};

export const ScoreAsYouGoSavedWorkNotice = {
  mounted(this: ScoreAsYouGoSavedWorkNoticeHook) {
    // LiveView destinations can mount before navigation has fully settled, so
    // consume immediately and again after LiveView reports page loading stop.
    this.consumeNotice = () => {
      const cleanup = mountSavedWorkNotice(this.el);
      if (cleanup) {
        this.cleanupSavedWorkNotice = cleanup;
      }
    };

    window.addEventListener('phx:page-loading-stop', this.consumeNotice);

    this.consumeNotice();
  },

  destroyed(this: ScoreAsYouGoSavedWorkNoticeHook) {
    this.cleanupSavedWorkNotice?.();

    if (this.consumeNotice) {
      window.removeEventListener('phx:page-loading-stop', this.consumeNotice);
    }
  },
};

export const initializeStaticScoreAsYouGoSavedWorkNotice = () => {
  // Controller-rendered pages do not mount Phoenix hooks, but they still load
  // app.ts. This initializer lets those pages consume the same notice payload.
  const noticeElement = document.querySelector<HTMLElement>('[data-sayg-saved-work-static="true"]');
  if (!noticeElement || noticeElement.dataset.initialized === 'true') return;

  mountSavedWorkNotice(noticeElement);
};
