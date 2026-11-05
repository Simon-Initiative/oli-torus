import type { AnalyticsEvent } from './catalog';

/** The page's analytics writer, installed by the head bootstrap in `analytics.js`. */
export interface TorusAnalyticsApi {
  context: unknown;
  pageView: (context: unknown) => void;
  track: (name: unknown, params?: unknown) => void;
}

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: (...args: unknown[]) => void;
    TorusAnalytics?: TorusAnalyticsApi;
  }
}

/**
 * Queues a catalogued product event with its current page context after consent and preview
 * checks. Returns before GTM processes it; callers never await analytics delivery.
 * Writer failures are contained so analytics cannot change the caller's result.
 * A no-op when analytics is not installed on the page.
 * Safe to import from any bundle: it never bundles the writer itself.
 */
export function track(event: AnalyticsEvent): void {
  try {
    window.TorusAnalytics?.track(event.name, event.params);
  } catch {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Analytics tracking failed; event dropped');
    }
  }
}
