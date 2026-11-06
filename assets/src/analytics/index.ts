import {
  CONSENT_CHANGED_EVENT,
  consentOptions,
  initializeConsent,
} from '../components/cookies/consent';
import {
  CONTEXT_PARAMETERS,
  EventContext,
  EventName,
  FileType,
  PageArea,
  clearedParameters,
  dataLayerEvent,
  eventParams,
  isValidValue,
} from './catalog';
import type { TorusAnalyticsApi } from './track';

export type PageContext = {
  page_path: string;
  page_area: PageArea;
  page_title: string;
  traffic_type: 'internal' | 'external';
} & EventContext;

type AnalyticsConfig = {
  container_id: string;
  auth?: string;
  preview?: string;
  context: PageContext;
  consent: unknown;
  consent_available: boolean;
  measurement_ids: string[];
  signed_in: boolean;
  media_url?: string;
};

const titles: Record<PageArea, string> = {
  delivery: 'Learning',
  instructor: 'Instructor',
  authoring: 'Authoring',
  admin: 'Administration',
  public: 'Torus',
};

const ENTERED_KEY = 'torus_analytics_entered';
const LESSON_CONTENT = '#page_content';
const DELIVERY_BUDGET_MS = 8;
const DEFERRED_TASK_TIMEOUT_MS = 1000;

type BrowserScheduler = {
  yield?: () => Promise<void>;
  postTask?: (callback: () => void, options: { priority: 'background' }) => Promise<unknown>;
};

const FILE_TYPES: Record<string, FileType> = {
  pdf: 'pdf',
  doc: 'doc',
  docx: 'doc',
  odt: 'doc',
  rtf: 'doc',
  ppt: 'slides',
  pptx: 'slides',
  odp: 'slides',
  key: 'slides',
  xls: 'sheet',
  xlsx: 'sheet',
  ods: 'sheet',
  csv: 'sheet',
  numbers: 'sheet',
  png: 'image',
  jpg: 'image',
  jpeg: 'image',
  gif: 'image',
  svg: 'image',
  webp: 'image',
};

const warn = (message: string) => {
  if (process.env.NODE_ENV !== 'production') console.warn(message);
};

function browserScheduler(): BrowserScheduler | undefined {
  return (window as Window & { scheduler?: BrowserScheduler }).scheduler;
}

// A starved native task falls back to a timer; its eventual callback must not run twice.
function scheduleTask(
  callback: () => void,
  nativeSchedule?: (run: () => void) => Promise<unknown>,
): void {
  let started = false;
  let fallback: number;
  const run = () => {
    if (started) return;
    started = true;
    window.clearTimeout(fallback);
    callback();
  };
  const fallbackSoon = () => {
    if (started) return;
    window.clearTimeout(fallback);
    fallback = window.setTimeout(run, 0);
  };
  fallback = window.setTimeout(run, nativeSchedule ? DEFERRED_TASK_TIMEOUT_MS : 0);
  if (!nativeSchedule) return;
  try {
    void nativeSchedule(run).catch(fallbackSoon);
  } catch {
    fallbackSoon();
  }
}

function yieldToMain(): Promise<void> {
  const scheduler = browserScheduler();
  const yieldTask = scheduler?.yield;
  return new Promise<void>((resolve) => {
    scheduleTask(
      resolve,
      typeof yieldTask === 'function' ? (run) => yieldTask.call(scheduler).then(run) : undefined,
    );
  });
}

function scheduleBackground(callback: () => void): void {
  const scheduler = browserScheduler();
  const postTask = scheduler?.postTask;
  scheduleTask(
    callback,
    typeof postTask === 'function'
      ? (run) => postTask.call(scheduler, run, { priority: 'background' })
      : undefined,
  );
}

// Only accept the server's route-level contract. Extra fields (including titles and
// URLs from future callers) are never copied into the data layer.
function sanitizeContext(value: unknown): PageContext | null {
  if (!value || typeof value !== 'object') return null;
  const context = value as Record<string, unknown>;
  if (
    typeof context.page_path !== 'string' ||
    !/^\/(?:[A-Za-z0-9_:/.*-]*)$/.test(context.page_path) ||
    typeof context.page_area !== 'string' ||
    !Object.prototype.hasOwnProperty.call(titles, context.page_area)
  ) {
    return null;
  }

  const page_area = context.page_area as PageArea;
  const sanitized: PageContext = {
    page_path: context.page_path,
    page_area,
    page_title: titles[page_area],
    traffic_type: context.traffic_type === 'internal' ? 'internal' : 'external',
  };
  for (const key of CONTEXT_PARAMETERS) {
    if (key !== 'page_area' && isValidValue(key, context[key])) {
      (sanitized as Record<string, unknown>)[key] = context[key];
    }
  }
  if (context.preview_mode === 'preview' || context.preview_mode === 'template_preview') {
    sanitized.preview_mode = context.preview_mode;
  }
  return sanitized;
}

function sanitizeMediaUrl(value: unknown): string | undefined {
  if (typeof value !== 'string' || !/^https?:\/\/[^\s]+$/.test(value)) return undefined;
  return value.endsWith('/') ? value : value + '/';
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
    signed_in: config.signed_in === true,
    media_url: sanitizeMediaUrl(config.media_url),
  };
}

// Only the coarse type leaves this function: never the URL, path or file name.
function linkedFileType(href: string, mediaUrl: string | undefined): FileType | null {
  let url: URL;
  try {
    url = new URL(href, window.location.href);
  } catch {
    return null;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
  const extension = /\.([A-Za-z0-9]+)$/.exec(url.pathname)?.[1].toLowerCase();
  if (extension && Object.prototype.hasOwnProperty.call(FILE_TYPES, extension)) {
    return FILE_TYPES[extension];
  }
  return mediaUrl && url.href.startsWith(mediaUrl) ? 'other' : null;
}

/**
 * Initializes Basic Consent Mode with deferred, ordered analytics delivery. Consent commands
 * remain immediate; no container or behavioral events load before opt-in.
 */
export function initializeAnalytics(value: unknown): void {
  const config = sanitizeConfig(value);
  if (window.TorusAnalytics || !config) return;

  initializeConsent(config.consent, {
    measurementAvailable: config.consent_available,
    measurementIds: config.measurement_ids,
    signedIn: config.signed_in,
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
  let lastQueuedPath = '';
  let containerRequested = false;
  let containerQueued = false;
  const enteredInMemory = new Set<string>();
  let pending: (() => void)[] = [];
  let nextPending = 0;
  let draining = false;

  const discardPending = () => {
    pending = [];
    nextPending = 0;
    containerQueued = false;
  };

  const deliverPending = (deadline?: number) => {
    while (nextPending < pending.length) {
      // Also guard delivery if consent changes without the normal notification handler.
      if (!isGranted()) {
        discardPending();
        break;
      }
      const deliver = pending[nextPending++];
      try {
        deliver();
      } catch {
        // GTM/tag failures must never reach an activity's success continuation.
        warn('Analytics delivery failed; event dropped');
      }
      // Startup has no scheduling pause between its initial context and loader. Consent
      // still gates each operation. Lifecycle flushes omit the deadline and send all pending work.
      if (deadline !== undefined && !containerQueued && performance.now() >= deadline) break;
    }
    pending = pending.slice(nextPending);
    nextPending = 0;
  };

  const drain = async (deferFirstBatch: boolean) => {
    try {
      if (deferFirstBatch) await yieldToMain();
      while (nextPending < pending.length) {
        deliverPending(performance.now() + DELIVERY_BUDGET_MS);
        // Inside postTask, yield retains background priority. Its timer fallback also bounds
        // the wait between batches if background continuations are starved.
        if (nextPending < pending.length) await yieldToMain();
      }
    } catch {
      discardPending();
      warn('Analytics delivery failed; pending events dropped');
    } finally {
      draining = false;
    }
  };

  const enqueue = (deliver: () => void) => {
    if (!isGranted()) return;
    pending.push(deliver);
    if (!draining) {
      draining = true;
      // Keep the initial page context and loader at the current priority for short visits.
      if (containerRequested) scheduleBackground(() => void drain(false));
      else void drain(true);
    }
  };

  // Course entry and preview launches count once per browser-tab session. Without session
  // storage (some LMS iframes), they count once per page load instead.
  const firstInTab = (key: string) => {
    try {
      const stored = JSON.parse(window.sessionStorage.getItem(ENTERED_KEY) || '[]');
      const keys: string[] = Array.isArray(stored)
        ? stored.filter((k): k is string => typeof k === 'string')
        : [];
      if (keys.includes(key)) return false;
      window.sessionStorage.setItem(ENTERED_KEY, JSON.stringify([...keys, key]));
      return true;
    } catch {
      if (enteredInMemory.has(key)) return false;
      enteredInMemory.add(key);
      return true;
    }
  };

  // Previews only measure their launch, so learner behavior never mixes with preview traffic.
  const send = (name: EventName, params: Record<string, string>, entryKey?: string) => {
    if (!isGranted()) return;
    const entry = dataLayerEvent(name, params, currentContext);
    if (currentContext.preview_mode && entry.feature_area !== 'preview') return;
    enqueue(() => {
      // Reserve tab entries only on delivery, so canceled visits do not consume their keys.
      if (entryKey !== undefined && !firstInTab(entryKey)) return;
      dataLayer.push(entry);
    });
  };

  const enterContext = (context: PageContext) => {
    if (context.preview_mode) {
      const feature_name =
        context.preview_mode === 'template_preview'
          ? 'template_preview_launched'
          : 'preview_launched';
      // The template slug is only a local tab key, never analytics context or payload.
      const templateSlug =
        context.preview_mode === 'template_preview'
          ? /^\/sections\/([^/]+)/.exec(window.location.pathname)?.[1]
          : undefined;
      send(
        'feature_used',
        { feature_name },
        `${context.preview_mode}:${templateSlug ?? context.course_id ?? ''}`,
      );
    } else if (
      context.course_id !== undefined &&
      (context.page_area === 'delivery' || context.page_area === 'instructor')
    ) {
      send('course_entered', {}, `course:${context.course_id}`);
    }
  };

  const analytics: TorusAnalyticsApi & { context: PageContext } = {
    context: currentContext,
    pageView(value: unknown) {
      const context = sanitizeContext(value);
      if (!context) return;
      currentContext = context;
      // Track the current route even while denied, so accepting never replays
      // the routes visited before consent or counts the initial LiveView mount.
      analytics.context = context;
      if (!isGranted()) return;
      if (context.page_path !== lastQueuedPath) {
        lastQueuedPath = context.page_path;
        const entry = {
          ...clearedParameters(),
          event: 'torus_page_view',
          page_path: context.page_path,
          page_area: context.page_area,
          page_title: context.page_title,
          traffic_type: context.traffic_type,
          user_role: context.user_role,
          course_id: context.course_id,
          page_type: context.page_type,
          page_location: window.location.origin + context.page_path,
          page_referrer: '',
        };
        enqueue(() => dataLayer.push(entry));
      }
      enterContext(context);
    },
    track(name: unknown, params?: unknown) {
      const result = eventParams(name, params);
      if (!result) {
        warn(`Dropped analytics event not in the catalog: ${String(name)}`);
        return;
      }
      if (result.dropped.length > 0) {
        warn(
          `Analytics event ${name} dropped parameters not allowed by the catalog: ` +
            result.dropped.join(', '),
        );
      }
      send(name as EventName, result.params);
    },
  };
  window.TorusAnalytics = analytics;

  const startMeasurement = () => {
    if (!isGranted()) return;
    analytics.pageView(currentContext);
    if (containerRequested || containerQueued) return;
    containerQueued = true;
    // Bootstrap shares the initial context's task, before any later event batches.
    enqueue(() => {
      try {
        if (containerRequested) return;
        dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });
        if (!isGranted()) return;
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
        containerRequested = true;
      } finally {
        containerQueued = false;
      }
    });
  };

  window.addEventListener('phx:analytics:page_view', (event: Event) => {
    analytics.pageView((event as CustomEvent<unknown>).detail);
  });
  // Server pushes (OliWeb.Analytics.track/3) and JS commands (js_track/3) share this channel.
  window.addEventListener('phx:analytics:track', (event: Event) => {
    const detail = (event as CustomEvent<unknown>).detail as Record<string, unknown> | null;
    if (detail && typeof detail === 'object') analytics.track(detail.name, detail.params);
  });
  // Capture phase, so content handlers that stop propagation cannot hide the click.
  document.addEventListener(
    'click',
    (event: MouseEvent) => {
      const anchor = event.target instanceof Element ? event.target.closest('a[href]') : null;
      if (!(anchor instanceof HTMLAnchorElement) || !anchor.closest(LESSON_CONTENT)) return;
      const file_type = linkedFileType(anchor.href, config.media_url);
      if (file_type) analytics.track('file_link_clicked', { file_type });
    },
    true,
  );
  window.addEventListener(CONSENT_CHANGED_EVENT, () => {
    if (isGranted()) {
      startMeasurement();
    } else {
      discardPending();
      // A later opt-in starts a new consented visit, including the current page.
      lastQueuedPath = '';
    }
  });
  // Capture lifecycle signals before tag handlers. This hands off pending events best-effort;
  // it cannot guarantee network delivery, particularly while GTM is still loading.
  window.addEventListener(
    'visibilitychange',
    () => {
      if (document.visibilityState === 'hidden') deliverPending();
    },
    true,
  );
  window.addEventListener('pagehide', () => deliverPending(), true);
  startMeasurement();
}
