export const CONSENT_VERSION = 2;
export const CONSENT_CHANGED_EVENT = 'torus:consent-changed';
export const CONSENT_PERSISTENCE_EVENT = 'torus:consent-persistence';
const PENDING_CONSENT_KEY = '_cky_pending_consent';
const STORAGE_PROBE_KEY = '_cky_consent_storage';
const CONSENT_DURATION = 365 * 24 * 60 * 60 * 1000;

export interface ConsentPreferences {
  necessary: true;
  functionality: boolean;
  analytics: boolean;
  targeting: false;
  version?: number;
}

export type ConsentPersistenceStatus = 'idle' | 'saving' | 'failed';

type Decision = { group: string; sequence: number };
type ConsentRequest = {
  preferences: ConsentPreferences;
  decision: Decision;
  expiresIso: string;
  requiresAcknowledgement: boolean;
};
type PendingWithdrawal = {
  version: number;
  preferences: ConsentPreferences;
  decision: Decision;
  expiresIso: string;
};

declare global {
  interface Window {
    TorusConsentState?: {
      preferences: ConsentPreferences;
      initialized: boolean;
      measurementIds: string[];
      measurementAvailable?: boolean;
      signedIn?: boolean;
      durableStorageAvailable?: boolean;
      decisionGroup?: string;
      decisionSequence?: number;
      pendingWithdrawal?: PendingWithdrawal;
      latestRequest?: ConsentRequest;
      persistenceStatus?: ConsentPersistenceStatus;
    };
  }
}

function browserCookies(): string {
  try {
    return document.cookie;
  } catch {
    return '';
  }
}

/** Reads one cookie defensively, including when iframe cookie access is blocked. */
export function readCookie(name: string): string {
  try {
    const entry = document.cookie.split(';').find((cookie) => cookie.trim().startsWith(`${name}=`));
    const value = entry ? entry.trim().slice(name.length + 1) : '';
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

function parsePending(value: string | null): PendingWithdrawal | undefined {
  try {
    const pending = JSON.parse(value || 'null');
    const preferences = pending?.preferences;
    const decision = pending?.decision;
    const expiration = Date.parse(pending?.expiresIso);
    if (
      pending?.version === CONSENT_VERSION &&
      preferences?.necessary === true &&
      typeof preferences.functionality === 'boolean' &&
      preferences.analytics === false &&
      preferences.targeting === false &&
      preferences.version === CONSENT_VERSION &&
      typeof decision?.group === 'string' &&
      /^[a-f0-9]{32}$/.test(decision.group) &&
      Number.isSafeInteger(decision.sequence) &&
      decision.sequence > 0 &&
      Number.isFinite(expiration) &&
      expiration > Date.now() &&
      expiration <= Date.now() + CONSENT_DURATION + 1000
    )
      return pending;
  } catch {
    // A malformed marker cannot change consent.
  }
  return undefined;
}

function sessionPending(): PendingWithdrawal | undefined {
  try {
    return parsePending(window.sessionStorage.getItem(PENDING_CONSENT_KEY));
  } catch {
    return undefined;
  }
}

function readPending(): PendingWithdrawal | undefined {
  const cookie = parsePending(readCookie(PENDING_CONSENT_KEY));
  const session = sessionPending();
  if (cookie && session && cookie.decision.group === session.decision.group) {
    return cookie.decision.sequence >= session.decision.sequence ? cookie : session;
  }
  return cookie || session;
}

function state() {
  if (!window.TorusConsentState) {
    const pending = readPending();
    window.TorusConsentState = {
      preferences: pending?.preferences ?? normalizeConsent(readCookie('_cky_opt_choices')),
      initialized: false,
      measurementIds: [],
      pendingWithdrawal: pending,
      decisionGroup: pending?.decision.group,
      decisionSequence: pending?.decision.sequence,
    };
  }
  return window.TorusConsentState;
}

function storageAvailable(): boolean {
  try {
    window.sessionStorage.setItem(STORAGE_PROBE_KEY, '1');
    const available = window.sessionStorage.getItem(STORAGE_PROBE_KEY) === '1';
    window.sessionStorage.removeItem(STORAGE_PROBE_KEY);
    if (available) return true;
  } catch {
    // When session storage is blocked, try a short-lived necessary cookie.
  }
  try {
    writeCookie(STORAGE_PROBE_KEY, '1', new Date(Date.now() + 1000));
    return readCookie(STORAGE_PROBE_KEY) === '1';
  } catch {
    return false;
  } finally {
    writeCookie(STORAGE_PROBE_KEY, '', new Date(0));
  }
}

/** Seeds browser state from the server while retaining an unacknowledged withdrawal. */
export function initializeConsent(
  preferences: unknown,
  options: { measurementAvailable?: boolean; measurementIds?: string[]; signedIn?: boolean } = {},
): ConsentPreferences {
  const current = state();
  if (options.measurementAvailable !== undefined)
    current.measurementAvailable = options.measurementAvailable;
  if (options.signedIn !== undefined) current.signedIn = options.signedIn;
  if (!current.initialized) {
    current.preferences = current.pendingWithdrawal?.preferences ?? normalizeConsent(preferences);
    current.initialized = true;
  }
  if (
    current.signedIn &&
    current.durableStorageAvailable === undefined &&
    !current.pendingWithdrawal
  ) {
    current.durableStorageAvailable = storageAvailable();
  }
  if (options.measurementIds) {
    current.measurementIds = Array.from(
      new Set([
        ...current.measurementIds,
        ...options.measurementIds.filter((id) => /^G-[A-Z0-9]+$/.test(id)),
      ]),
    );
    const analytics = consentOptions().analytics && current.measurementAvailable !== false;
    updateGoogleDisabled(analytics);
    if (!analytics) deleteAnalyticsCookies();
  }
  return consentOptions();
}

/** Returns effective preferences; pending withdrawals and unavailable durable storage deny tracking. */
export function consentOptions(): ConsentPreferences {
  const current = state();
  if (current.pendingWithdrawal) return { ...current.preferences, analytics: false };
  const unavailable = current.signedIn && current.durableStorageAvailable === false;
  return { ...current.preferences, analytics: !unavailable && current.preferences.analytics };
}

/** Whether a valid withdrawal still requires acknowledgement from the server. */
export function hasPendingWithdrawal(): boolean {
  return state().pendingWithdrawal !== undefined;
}

/** Returns the shared status used by desktop, banner and mobile persistence feedback. */
export function consentPersistenceStatus(): ConsentPersistenceStatus {
  return state().persistenceStatus ?? 'idle';
}

function setPersistenceStatus(status: ConsentPersistenceStatus) {
  const current = state();
  if (current.persistenceStatus === status) return;
  current.persistenceStatus = status;
  window.dispatchEvent(new CustomEvent(CONSENT_PERSISTENCE_EVENT, { detail: status }));
}

/** Reports whether consent is decided for the current policy version. */
export function hasCurrentDecision(): boolean {
  return consentOptions().version === CONSENT_VERSION;
}

function writeCookie(name: string, value: string, expiration?: Date) {
  try {
    document.cookie = `${name}=${encodeURIComponent(value)};path=/;SameSite=None;Secure${
      expiration ? `;expires=${expiration.toUTCString()}` : ''
    }`;
  } catch {
    // sessionStorage retains pending withdrawals when iframe cookies cannot be written.
  }
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
  const cookieIds = browserCookies()
    .split(';')
    .flatMap((cookie) => {
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

/** Deletes root-path host-only and current-host GA4 cookies without altering shared parent domains. */
export function deleteAnalyticsCookies(): void {
  const names = browserCookies()
    .split(';')
    .map((cookie) => cookie.trim().split('=')[0])
    .filter((name) => name === '_ga' || name.startsWith('_ga_'));
  const domains = ['', window.location.hostname];
  for (const name of names) {
    for (const domain of domains) {
      try {
        document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;max-age=0;path=/${
          domain ? `;domain=${domain}` : ''
        };SameSite=None;Secure`;
      } catch {
        // A blocked cookie store cannot be cleaned, but GA remains disabled.
      }
    }
  }
}

function applyConsent(): void {
  const current = state();
  const preferences = consentOptions();
  const analytics = preferences.analytics && current.measurementAvailable !== false;
  updateGoogleDisabled(analytics);
  window.gtag?.('consent', 'update', {
    analytics_storage: analytics ? 'granted' : 'denied',
    ad_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
  });
  if (!analytics) deleteAnalyticsCookies();
  window.dispatchEvent(new CustomEvent(CONSENT_CHANGED_EVENT, { detail: preferences }));
}

function sameDecision(first: Decision | undefined, second: Decision | undefined): boolean {
  return !!first && !!second && first.group === second.group && first.sequence === second.sequence;
}

function retainWithdrawal(request: ConsentRequest) {
  const pending: PendingWithdrawal = {
    version: CONSENT_VERSION,
    preferences: request.preferences,
    decision: request.decision,
    expiresIso: request.expiresIso,
  };
  const current = state();
  current.pendingWithdrawal = pending;
  const value = JSON.stringify(pending);
  writeCookie(PENDING_CONSENT_KEY, value, new Date(request.expiresIso));
  try {
    window.sessionStorage.setItem(PENDING_CONSENT_KEY, value);
  } catch {
    // A writable cookie still preserves withdrawal across navigation.
  }
}

function clearWithdrawal() {
  const current = state();
  const decision = current.pendingWithdrawal?.decision;
  if (sameDecision(parsePending(readCookie(PENDING_CONSENT_KEY))?.decision, decision)) {
    writeCookie(PENDING_CONSENT_KEY, '', new Date(0));
  }
  if (sameDecision(sessionPending()?.decision, decision)) {
    try {
      window.sessionStorage.removeItem(PENDING_CONSENT_KEY);
    } catch {
      // The cookie or current in-memory state still governs this page.
    }
  }
  current.pendingWithdrawal = readPending();
  if (
    current.signedIn &&
    current.durableStorageAvailable === undefined &&
    !current.pendingWithdrawal
  ) {
    current.durableStorageAvailable = storageAvailable();
  }
}

function isLatest(current: ReturnType<typeof state>, request: ConsentRequest) {
  return window.TorusConsentState === current && current.latestRequest === request;
}

async function persistConsent(request: ConsentRequest): Promise<void> {
  const current = state();
  setPersistenceStatus('saving');
  const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
  const cookies = [
    {
      name: '_cky_opt_choices',
      value: JSON.stringify(request.preferences),
      expiresIso: request.expiresIso,
    },
    { name: '_cky_opt_in', value: 'true', expiresIso: request.expiresIso },
  ];
  try {
    const response = await fetch('/consent/cookie', {
      method: 'POST',
      credentials: 'same-origin',
      keepalive: true,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(csrf ? { 'X-CSRF-Token': csrf } : {}),
      },
      body: JSON.stringify({ cookies, decision: request.decision }),
    });
    if (!response.ok) throw new Error('Consent persistence failed');
    if (request.requiresAcknowledgement) {
      const result = await response.json();
      if (result.acknowledged !== true || !sameDecision(result.decision, request.decision)) {
        throw new Error('Consent was not acknowledged');
      }
    }
    if (!isLatest(current, request)) return;
    const previouslyGranted = consentOptions().analytics;
    clearWithdrawal();
    setPersistenceStatus('idle');
    if (previouslyGranted !== consentOptions().analytics) applyConsent();
  } catch {
    if (isLatest(current, request)) setPersistenceStatus('failed');
  }
}

/** Stores a choice immediately; signed-in withdrawal stays denied until matching acknowledgement. */
export async function saveConsent(
  preferences: Pick<ConsentPreferences, 'functionality' | 'analytics'>,
  options: { persist?: boolean } = {},
): Promise<void> {
  const chosen = normalizeConsent({ ...preferences, version: CONSENT_VERSION });
  const current = state();
  current.preferences = chosen;
  current.initialized = true;
  const expiration = new Date(Date.now() + CONSENT_DURATION);
  let request: ConsentRequest | undefined;
  if (options.persist !== false) {
    current.decisionGroup ??= Array.from(
      window.crypto.getRandomValues(new Uint8Array(16)),
      (byte) => byte.toString(16).padStart(2, '0'),
    ).join('');
    current.decisionSequence = (current.decisionSequence ?? 0) + 1;
    request = {
      preferences: chosen,
      decision: { group: current.decisionGroup, sequence: current.decisionSequence },
      expiresIso: expiration.toISOString(),
      requiresAcknowledgement: current.signedIn === true || current.pendingWithdrawal !== undefined,
    };
    current.latestRequest = request;
    if (!chosen.analytics && request.requiresAcknowledgement) retainWithdrawal(request);
  }
  writeCookie('_cky_opt_choices', JSON.stringify(chosen), expiration);
  writeCookie('_cky_opt_in', 'true', expiration);
  writeCookie('_cky_opt_in_dismiss', '', new Date(0));
  applyConsent();
  if (request) await persistConsent(request);
}

function restoredRequest(): ConsentRequest | undefined {
  const pending = state().pendingWithdrawal;
  return pending ? { ...pending, requiresAcknowledgement: true } : undefined;
}

/** Resumes an unacknowledged withdrawal once after page bootstrap, reusing its original order. */
export async function resumePendingConsent(): Promise<void> {
  const current = state();
  if (current.latestRequest || !current.pendingWithdrawal) return;
  const request = restoredRequest();
  if (!request) return;
  current.latestRequest = request;
  await persistConsent(request);
}

/** Retries the latest unsuccessful save without inventing a new decision or expiry. */
export async function retryConsent(): Promise<void> {
  const current = state();
  if (consentPersistenceStatus() === 'saving') return;
  const request = current.latestRequest ?? restoredRequest();
  if (!request) return;
  current.latestRequest = request;
  await persistConsent(request);
}
