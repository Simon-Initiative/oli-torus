export const CONSENT_VERSION = 2;
export const CONSENT_CHANGED_EVENT = 'torus:consent-changed';
const CONSENT_DURATION = 365 * 24 * 60 * 60 * 1000;

export interface ConsentPreferences {
  necessary: true;
  functionality: boolean;
  analytics: boolean;
  targeting: false;
  version?: number;
}

declare global {
  interface Window {
    TorusConsentState?: {
      preferences: ConsentPreferences;
      initialized: boolean;
      measurementIds: string[];
      measurementAvailable?: boolean;
      decisionGroup?: string;
      decisionSequence?: number;
    };
  }
}

/** Reads one cookie defensively, supporting both legacy raw and encoded values. */
export function readCookie(name: string): string {
  const entry = document.cookie.split(';').find((cookie) => cookie.trim().startsWith(`${name}=`));
  const value = entry ? entry.trim().slice(name.length + 1) : '';
  try {
    return decodeURIComponent(value);
  } catch {
    return '';
  }
}

/** Preserves functional choices while requiring an explicit current-version analytics decision. */
export function normalizeConsent(value: unknown): ConsentPreferences {
  let parsed = value;
  try {
    if (typeof parsed === 'string') parsed = JSON.parse(parsed);
  } catch {
    parsed = null;
  }
  const preferences =
    parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : {};
  const current =
    preferences.version === CONSENT_VERSION && typeof preferences.analytics === 'boolean';
  return {
    necessary: true,
    functionality: preferences.functionality !== false,
    analytics: current && preferences.analytics === true,
    targeting: false,
    ...(current ? { version: CONSENT_VERSION } : {}),
  };
}

function state() {
  return (window.TorusConsentState ||= {
    preferences: normalizeConsent(readCookie('_cky_opt_choices')),
    initialized: false,
    measurementIds: [],
  });
}

/** Seeds the shared browser state once from the authoritative server-rendered decision. */
export function initializeConsent(
  preferences: unknown,
  options: { measurementAvailable?: boolean; measurementIds?: string[] } = {},
): ConsentPreferences {
  const current = state();
  if (options.measurementAvailable !== undefined) {
    current.measurementAvailable = options.measurementAvailable;
  }
  if (!current.initialized) {
    current.preferences = normalizeConsent(preferences);
    current.initialized = true;
  }
  if (options.measurementIds) {
    current.measurementIds = Array.from(
      new Set([
        ...current.measurementIds,
        ...options.measurementIds.filter((id) => /^G-[A-Z0-9]+$/.test(id)),
      ]),
    );
    const analytics = current.preferences.analytics && current.measurementAvailable !== false;
    updateGoogleDisabled(analytics);
    if (!analytics) deleteAnalyticsCookies();
  }
  return { ...current.preferences };
}

/** Returns the effective choice, shared between the head analytics bundle and application bundle. */
export function consentOptions(): ConsentPreferences {
  return { ...state().preferences };
}

/** Reports whether consent is decided for the current policy version. */
export function hasCurrentDecision(): boolean {
  return consentOptions().version === CONSENT_VERSION;
}

function writeCookie(name: string, value: string, expiration?: Date) {
  document.cookie = `${name}=${encodeURIComponent(value)};path=/;SameSite=None;Secure${
    expiration ? `;expires=${expiration.toUTCString()}` : ''
  }`;
}

/** Suppresses the current banner for this browser session without making a consent decision. */
export function dismissConsent(): void {
  writeCookie('_cky_opt_in_dismiss', String(CONSENT_VERSION));
}

/** Returns true when a previous close action dismissed this version for the current session. */
export function isConsentDismissed(): boolean {
  return readCookie('_cky_opt_in_dismiss') === String(CONSENT_VERSION);
}

function updateGoogleDisabled(analytics: boolean) {
  const current = state();
  const cookieIds = document.cookie.split(';').flatMap((cookie) => {
    const match = cookie.trim().match(/^_ga_([A-Z0-9]+)=/i);
    return match ? [`G-${match[1]}`] : [];
  });
  const knownIds = Object.keys(window).flatMap((key) =>
    key.startsWith('ga-disable-G-') ? [key.slice('ga-disable-'.length)] : [],
  );
  current.measurementIds = Array.from(
    new Set([...current.measurementIds, ...cookieIds, ...knownIds]),
  );
  for (const id of current.measurementIds) {
    (window as unknown as Record<string, unknown>)[`ga-disable-${id}`] = !analytics;
  }
}

/** Deletes host-only and current-host GA4 cookies without altering shared parent domains. */
export function deleteAnalyticsCookies(): void {
  const names = document.cookie
    .split(';')
    .map((cookie) => cookie.trim().split('=')[0])
    .filter((name) => name === '_ga' || name.startsWith('_ga_'));
  const domains = ['', window.location.hostname];
  const pathParts = window.location.pathname.split('/').filter(Boolean);
  const paths = [
    '/',
    ...pathParts.map((_, index) => `/${pathParts.slice(0, index + 1).join('/')}`),
  ];
  for (const name of names) {
    for (const domain of domains) {
      for (const path of paths) {
        document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;max-age=0;path=${path}${
          domain ? `;domain=${domain}` : ''
        };SameSite=None;Secure`;
      }
    }
  }
}

/** Stores and applies an explicit choice immediately, then persists it for signed-in users. */
export async function saveConsent(
  preferences: Pick<ConsentPreferences, 'functionality' | 'analytics'>,
  options: { persist?: boolean } = {},
): Promise<void> {
  const chosen = normalizeConsent({ ...preferences, version: CONSENT_VERSION });
  const current = state();
  current.preferences = chosen;
  current.initialized = true;
  const analytics = chosen.analytics && current.measurementAvailable !== false;
  const expiration = new Date(Date.now() + CONSENT_DURATION);
  const cookies = [
    {
      name: '_cky_opt_choices',
      value: JSON.stringify(chosen),
      expiresIso: expiration.toISOString(),
    },
    { name: '_cky_opt_in', value: 'true', expiresIso: expiration.toISOString() },
  ];
  cookies.forEach((cookie) => writeCookie(cookie.name, cookie.value, expiration));
  writeCookie('_cky_opt_in_dismiss', '', new Date(0));
  updateGoogleDisabled(analytics);
  window.gtag?.('consent', 'update', {
    analytics_storage: analytics ? 'granted' : 'denied',
    ad_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
  });
  if (!analytics) deleteAnalyticsCookies();
  window.dispatchEvent(new CustomEvent(CONSENT_CHANGED_EVENT, { detail: chosen }));

  if (options.persist === false) return;
  const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
  // This transient document group orders overlapping saves on the server. It is never stored in
  // browser cookies or sent to analytics, and every request starts before navigation can unload us.
  current.decisionGroup ??= Array.from(window.crypto.getRandomValues(new Uint8Array(16)), (byte) =>
    byte.toString(16).padStart(2, '0'),
  ).join('');
  current.decisionSequence = (current.decisionSequence ?? 0) + 1;
  const decision = { group: current.decisionGroup, sequence: current.decisionSequence };
  try {
    await fetch('/consent/cookie', {
      method: 'POST',
      credentials: 'same-origin',
      keepalive: true,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(csrf ? { 'X-CSRF-Token': csrf } : {}),
      },
      body: JSON.stringify({ cookies, decision }),
    });
  } catch {
    // The browser choice still applies if persistence is temporarily unavailable.
  }
}
