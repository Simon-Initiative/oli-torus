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
 * Sends a catalogued product event to the page's analytics writer, which adds context and
 * applies consent and preview rules. A no-op when analytics is not installed on the page.
 * Safe to import from any bundle: it never bundles the writer itself.
 */
export function track(event: AnalyticsEvent): void {
  window.TorusAnalytics?.track(event.name, event.params);
}
