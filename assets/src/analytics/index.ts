import {
  CONSENT_CHANGED_EVENT,
  consentOptions,
  initializeConsent,
} from '../components/cookies/consent';

type PageArea = 'delivery' | 'instructor' | 'authoring' | 'admin' | 'public';

export type PageContext = {
  page_path: string;
  page_area: PageArea;
  page_title: string;
  traffic_type: 'internal' | 'external';
};

type AnalyticsConfig = {
  container_id: string;
  auth?: string;
  preview?: string;
  context: PageContext;
  consent: unknown;
  consent_available: boolean;
  measurement_ids: string[];
};

const titles: Record<PageArea, string> = {
  delivery: 'Learning',
  instructor: 'Instructor',
  authoring: 'Authoring',
  admin: 'Administration',
  public: 'Torus',
};

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: (...args: unknown[]) => void;
    TorusAnalytics?: { pagePath: string; pageView: (context: unknown) => void };
  }
}

// Only accept the server's route-level contract. Extra fields (including titles and
// URLs from future callers) are never copied into the data layer.
function sanitizeContext(value: unknown): PageContext | null {
  if (!value || typeof value !== 'object') return null;
  const context = value as Partial<PageContext>;
  if (
    typeof context.page_path !== 'string' ||
    !/^\/(?:[A-Za-z0-9_:/.*-]*)$/.test(context.page_path) ||
    typeof context.page_area !== 'string' ||
    !Object.prototype.hasOwnProperty.call(titles, context.page_area)
  ) {
    return null;
  }

  return {
    page_path: context.page_path,
    page_area: context.page_area,
    page_title: titles[context.page_area],
    traffic_type: context.traffic_type === 'internal' ? 'internal' : 'external',
  };
}

function sanitizeConfig(value: unknown): AnalyticsConfig | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const config = value as Record<string, unknown>;
  const context = sanitizeContext(config.context);
  if (
    typeof config.container_id !== 'string' ||
    !/^GTM-[A-Z0-9]+$/.test(config.container_id) ||
    !Array.isArray(config.measurement_ids) ||
    config.measurement_ids.length === 0 ||
    !config.measurement_ids.every((id) => typeof id === 'string' && /^G-[A-Z0-9]+$/.test(id)) ||
    !context
  ) {
    return null;
  }

  const { auth, preview } = config;
  if (
    (auth != null || preview != null) &&
    (typeof auth !== 'string' ||
      !/^[A-Za-z0-9_-]+$/.test(auth) ||
      typeof preview !== 'string' ||
      !/^env-[0-9]+$/.test(preview))
  ) {
    return null;
  }

  return {
    container_id: config.container_id,
    auth: typeof auth === 'string' ? auth : undefined,
    preview: typeof preview === 'string' ? preview : undefined,
    context,
    consent: config.consent,
    consent_available: config.consent_available === true,
    measurement_ids: config.measurement_ids,
  };
}

/** Initializes Basic Consent Mode; no container or behavioral events load before opt-in. */
export function initializeAnalytics(value: unknown): void {
  const config = sanitizeConfig(value);
  if (window.TorusAnalytics || !config) return;

  initializeConsent(config.consent, {
    measurementAvailable: config.consent_available,
    measurementIds: config.measurement_ids,
  });
  const isGranted = () => config.consent_available && consentOptions().analytics;
  const dataLayer = (window.dataLayer = window.dataLayer || []);
  // Google expects an Arguments object for the gtag command queue.
  window.gtag = function () {
    // eslint-disable-next-line prefer-rest-params
    dataLayer.push(arguments);
  };
  window.gtag('consent', 'default', {
    analytics_storage: isGranted() ? 'granted' : 'denied',
    ad_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
  });

  let currentContext = config.context;
  let lastSentPath = '';
  let containerLoaded = false;
  const analytics = {
    pagePath: currentContext.page_path,
    pageView(value: unknown) {
      const context = sanitizeContext(value);
      if (!context) return;
      currentContext = context;
      // Track the current route even while denied, so accepting never replays
      // the routes visited before consent or counts the initial LiveView mount.
      analytics.pagePath = context.page_path;
      if (!isGranted() || context.page_path === lastSentPath) return;
      lastSentPath = context.page_path;
      dataLayer.push({
        event: 'torus_page_view',
        ...context,
        page_location: window.location.origin + context.page_path,
        page_referrer: '',
      });
    },
  };
  window.TorusAnalytics = analytics;

  const startMeasurement = () => {
    if (!isGranted()) return;
    analytics.pageView(currentContext);
    if (containerLoaded) return;
    containerLoaded = true;
    dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });
    const loader = document.createElement('script');
    loader.async = true;
    // The request itself must not carry a token-bearing Torus path or LMS referrer.
    loader.referrerPolicy = 'no-referrer';
    const params = new URLSearchParams({ id: config.container_id });
    if (config.auth && config.preview) {
      params.set('gtm_auth', config.auth);
      params.set('gtm_preview', config.preview);
      params.set('gtm_cookies_win', 'x');
    }
    loader.src = 'https://www.googletagmanager.com/gtm.js?' + params.toString();
    document.head.appendChild(loader);
  };

  window.addEventListener('phx:analytics:page_view', (event: Event) => {
    analytics.pageView((event as CustomEvent<unknown>).detail);
  });
  window.addEventListener(CONSENT_CHANGED_EVENT, () => {
    if (isGranted()) {
      startMeasurement();
    } else {
      // A later opt-in starts a new consented visit, including the current page.
      lastSentPath = '';
    }
  });
  startMeasurement();
}
