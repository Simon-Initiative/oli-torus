/** @jest-environment-options {"url":"https://torus.example.test/courses/lesson"} */
import {
  consentOptions,
  consentPersistenceStatus,
  hasPendingWithdrawal,
  initializeConsent,
  readCookie,
  resumePendingConsent,
  retryConsent,
  saveConsent,
} from '../../../src/components/cookies/consent';
import { retrieveCookies } from '../../../src/components/cookies/utils';

const markerKey = '_cky_pending_consent';
const cookieDescriptor = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie')!;
const accepted = {
  necessary: true,
  functionality: true,
  analytics: true,
  targeting: false,
  version: 2,
};
const rejected = { ...accepted, analytics: false };
const decision = { group: 'a'.repeat(32), sequence: 2 };
const marker = () => ({
  version: 2,
  preferences: rejected,
  decision,
  expiresIso: new Date(Date.now() + 86400000).toISOString(),
});
const acknowledge = (body: string) => ({
  ok: true,
  json: async () => ({
    persistence: 'persisted',
    acknowledged: true,
    decision: JSON.parse(body).decision,
  }),
});
const deferred = () => {
  let finish: (value: unknown) => void = () => undefined;
  const promise = new Promise((resolve) => {
    finish = resolve;
  });
  return { promise, finish };
};
function boot() {
  initializeConsent(accepted, {
    signedIn: true,
    measurementAvailable: true,
    measurementIds: ['G-ABC123'],
  });
}
function storeMarker(value = marker()) {
  document.cookie = `${markerKey}=${encodeURIComponent(JSON.stringify(value))};path=/;Secure`;
  sessionStorage.setItem(markerKey, JSON.stringify(value));
}

beforeEach(() => {
  Object.defineProperty(Document.prototype, 'cookie', cookieDescriptor);
  delete window.TorusConsentState;
  window.sessionStorage.clear();
  document.cookie.split(';').forEach((cookie) => {
    document.cookie = `${cookie.trim().split('=')[0]}=;max-age=0;path=/;Secure`;
  });
  Object.keys(window)
    .filter((key) => key.startsWith('ga-disable-G-'))
    .forEach((key) => {
      delete (window as unknown as Record<string, unknown>)[key];
    });
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
  window.gtag = jest.fn();
  global.fetch = jest.fn().mockImplementation(async (_url, options) => acknowledge(options.body));
});
afterEach(() => {
  jest.restoreAllMocks();
  Object.defineProperty(Document.prototype, 'cookie', cookieDescriptor);
  window.sessionStorage.clear();
});

test('pending withdrawal survives navigation and resumes with its original order', async () => {
  boot();
  const first = deferred();
  (fetch as jest.Mock).mockImplementationOnce(() => first.promise);
  const save = saveConsent(rejected);
  const original = JSON.parse((fetch as jest.Mock).mock.calls[0][1].body);
  expect(JSON.parse(readCookie(markerKey)).decision).toEqual(original.decision);
  expect(consentPersistenceStatus()).toBe('saving');
  delete window.TorusConsentState;
  boot();
  expect(consentOptions().analytics).toBe(false);
  expect(hasPendingWithdrawal()).toBe(true);
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(true);
  first.finish(acknowledge(JSON.stringify(original)));
  await save;
  expect(hasPendingWithdrawal()).toBe(true);
  await resumePendingConsent();
  expect(JSON.parse((fetch as jest.Mock).mock.calls[1][1].body)).toEqual(original);
  expect(readCookie(markerKey)).toBe('');
  expect(sessionStorage.getItem(markerKey)).toBeNull();
  expect(consentPersistenceStatus()).toBe('idle');
  expect(consentOptions().analytics).toBe(false);
  delete window.TorusConsentState;
  boot();
  expect(consentOptions().analytics).toBe(true);
});

test('session storage retains denial when iframe cookies are blocked', async () => {
  sessionStorage.setItem(markerKey, JSON.stringify(marker()));
  jest.spyOn(Document.prototype, 'cookie', 'get').mockReturnValue('');
  jest.spyOn(Document.prototype, 'cookie', 'set').mockImplementation(() => undefined);
  boot();
  expect(consentOptions().analytics).toBe(false);
  await resumePendingConsent();
  expect(sessionStorage.getItem(markerKey)).toBeNull();
  expect(consentOptions().analytics).toBe(false);
  expect(consentPersistenceStatus()).toBe('idle');
});

test('cookie storage retains denial when session storage is unavailable', async () => {
  jest.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
    throw new Error('blocked');
  });
  jest.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
    throw new Error('blocked');
  });
  boot();
  (fetch as jest.Mock).mockResolvedValueOnce({ ok: false });
  await saveConsent(rejected);
  expect(readCookie(markerKey)).not.toBe('');
  delete window.TorusConsentState;
  boot();
  expect(consentOptions().analytics).toBe(false);
  await resumePendingConsent();
  expect(readCookie(markerKey)).toBe('');
  expect(consentPersistenceStatus()).toBe('idle');
});

test('both stores throwing keeps signed-in measurement denied across fresh loads', async () => {
  jest.spyOn(window, 'sessionStorage', 'get').mockImplementation(() => {
    throw new Error('blocked');
  });
  jest.spyOn(Document.prototype, 'cookie', 'get').mockImplementation(() => {
    throw new Error('blocked');
  });
  jest.spyOn(Document.prototype, 'cookie', 'set').mockImplementation(() => {
    throw new Error('blocked');
  });
  expect(boot).not.toThrow();
  expect(consentOptions().analytics).toBe(false);
  (fetch as jest.Mock).mockResolvedValueOnce({ ok: false });
  await saveConsent(rejected);
  expect(consentPersistenceStatus()).toBe('failed');
  delete window.TorusConsentState;
  expect(boot).not.toThrow();
  expect(consentOptions().analytics).toBe(false);
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(true);
});

test.each([403, 422, 500, 503])(
  'HTTP %s retains denial and Retry reuses the exact request',
  async (status) => {
    boot();
    (fetch as jest.Mock).mockResolvedValueOnce({ ok: false, status });
    await saveConsent(rejected);
    const original = (fetch as jest.Mock).mock.calls[0][1];
    expect(consentPersistenceStatus()).toBe('failed');
    expect(hasPendingWithdrawal()).toBe(true);
    expect(consentOptions().analytics).toBe(false);
    await retryConsent();
    expect((fetch as jest.Mock).mock.calls[1][1].body).toBe(original.body);
    expect((fetch as jest.Mock).mock.calls[1][1].keepalive).toBe(true);
    expect(consentPersistenceStatus()).toBe('idle');
    expect(hasPendingWithdrawal()).toBe(false);
  },
);

test('network failure and mismatched acknowledgement cannot clear denial', async () => {
  boot();
  (fetch as jest.Mock).mockRejectedValueOnce(new Error('offline'));
  await saveConsent(rejected);
  expect(consentPersistenceStatus()).toBe('failed');
  (fetch as jest.Mock).mockResolvedValueOnce({
    ok: true,
    json: async () => ({ acknowledged: true, decision: { ...decision, group: 'b'.repeat(32) } }),
  });
  await retryConsent();
  expect(consentPersistenceStatus()).toBe('failed');
  expect(hasPendingWithdrawal()).toBe(true);
  await retryConsent();
  expect(hasPendingWithdrawal()).toBe(false);
});

test('an expired signed-in session cannot acknowledge withdrawal as browser-only', async () => {
  boot();
  (fetch as jest.Mock).mockResolvedValueOnce({
    ok: true,
    json: async () => ({ persistence: 'browser_only', acknowledged: false }),
  });
  await saveConsent(rejected);
  expect(hasPendingWithdrawal()).toBe(true);
  expect(consentPersistenceStatus()).toBe('failed');
});

test('anonymous choices need no database acknowledgement', async () => {
  initializeConsent({}, { signedIn: false });
  (fetch as jest.Mock).mockResolvedValueOnce({
    ok: true,
    json: async () => ({ persistence: 'browser_only', acknowledged: false }),
  });
  await saveConsent(rejected);
  expect(hasPendingWithdrawal()).toBe(false);
  expect(consentPersistenceStatus()).toBe('idle');
  expect(readCookie('_cky_opt_choices')).toContain('"analytics":false');
});

test('reacceptance waits for its own acknowledgement, ignoring an older failed withdrawal', async () => {
  boot();
  const first = deferred();
  const second = deferred();
  (fetch as jest.Mock)
    .mockImplementationOnce(() => first.promise)
    .mockImplementationOnce(() => second.promise);
  const reject = saveConsent(rejected);
  const accept = saveConsent(accepted);
  expect(consentOptions().analytics).toBe(false);
  const requests = (fetch as jest.Mock).mock.calls.map(([, options]) => options.body);
  expect(JSON.parse(requests[1]).decision.sequence).toBe(
    JSON.parse(requests[0]).decision.sequence + 1,
  );
  second.finish(acknowledge(requests[1]));
  await accept;
  expect(consentOptions().analytics).toBe(true);
  expect(hasPendingWithdrawal()).toBe(false);
  first.finish({ ok: false });
  await reject;
  expect(consentPersistenceStatus()).toBe('idle');
  expect(consentOptions().analytics).toBe(true);
});

test('older acceptance success cannot clear a newer failed withdrawal', async () => {
  boot();
  const first = deferred();
  (fetch as jest.Mock)
    .mockImplementationOnce(() => first.promise)
    .mockResolvedValueOnce({ ok: false });
  const accept = saveConsent(accepted);
  await saveConsent(rejected);
  first.finish(acknowledge((fetch as jest.Mock).mock.calls[0][1].body));
  await accept;
  expect(consentPersistenceStatus()).toBe('failed');
  expect(consentOptions().analytics).toBe(false);
  expect(hasPendingWithdrawal()).toBe(true);
});

test('page-ready initialization automatically resumes pending denial', async () => {
  storeMarker();
  await retrieveCookies('/consent/cookie', {
    preferences: accepted,
    signedIn: true,
    privacyPoliciesUrl: '/privacy',
  });
  expect(fetch).toHaveBeenCalledTimes(1);
  expect(JSON.parse((fetch as jest.Mock).mock.calls[0][1].body).decision).toEqual(decision);
  expect(hasPendingWithdrawal()).toBe(false);
  expect(consentOptions().analytics).toBe(false);
});

test.each([
  { ...marker(), version: 1 },
  { ...marker(), preferences: accepted },
  { ...marker(), preferences: { ...rejected, necessary: false } },
  { ...marker(), decision: { ...decision, sequence: 0 } },
  { ...marker(), expiresIso: new Date(0).toISOString() },
])('invalid or expired pending marker cannot override server consent: %j', (pending) => {
  storeMarker(pending);
  boot();
  expect(consentOptions().analytics).toBe(true);
  expect(hasPendingWithdrawal()).toBe(false);
});
