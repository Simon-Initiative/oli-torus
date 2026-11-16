/** @jest-environment-options {"url":"https://torus.example.test/cookie-preferences"} */
import {
  consentOptions,
  consentPersistenceStatus,
  hasPendingWithdrawal,
  initializeConsent,
  readCookie,
} from '../../src/components/cookies/consent';
import { SaveCookiePreferences } from '../../src/hooks/save_cookie_preferences';

const rejected = { functionality: false, analytics: false, version: 2 };

function mountedSave() {
  const hook = { pushEvent: jest.fn(), handleEvent: jest.fn() };
  SaveCookiePreferences.mounted.call(hook);
  return hook.handleEvent.mock.calls[0][1];
}

beforeEach(() => {
  delete window.TorusConsentState;
  window.sessionStorage.clear();
  document.cookie.split(';').forEach((cookie) => {
    document.cookie = `${cookie.trim().split('=')[0]}=;max-age=0;path=/;Secure`;
  });
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
  window.gtag = jest.fn();
  global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 503 });
});

afterEach(() => {
  jest.restoreAllMocks();
  window.sessionStorage.clear();
});

test('an authenticated withdrawal before bootstrap retains denial after a failed save', async () => {
  const save = mountedSave();
  await save({ preferences: rejected, is_authenticated: true });

  expect(window.TorusConsentState?.signedIn).toBe(true);
  expect(consentOptions().analytics).toBe(false);
  expect(hasPendingWithdrawal()).toBe(true);
  expect(consentPersistenceStatus()).toBe('failed');
  expect(JSON.parse(readCookie('_cky_pending_consent')).preferences.analytics).toBe(false);
  expect(fetch).toHaveBeenCalledWith(
    '/consent/cookie',
    expect.objectContaining({ headers: expect.objectContaining({ 'X-CSRF-Token': 'csrf-value' }) }),
  );
});

test('a missing authentication flag preserves the bootstrap state and measurement restrictions', async () => {
  initializeConsent({}, { signedIn: true, measurementAvailable: false });
  await mountedSave()({ preferences: rejected });

  expect(window.TorusConsentState?.signedIn).toBe(true);
  expect(window.TorusConsentState?.measurementAvailable).toBe(false);
  expect(hasPendingWithdrawal()).toBe(true);
  expect(consentPersistenceStatus()).toBe('failed');
});

test('an explicit anonymous flag allows browser-only persistence after authentication changes', async () => {
  initializeConsent({}, { signedIn: true, measurementAvailable: false });
  (fetch as jest.Mock).mockResolvedValue({
    ok: true,
    json: async () => ({ persistence: 'browser_only', acknowledged: false }),
  });
  await mountedSave()({ preferences: rejected, is_authenticated: false });

  expect(window.TorusConsentState?.signedIn).toBe(false);
  expect(window.TorusConsentState?.measurementAvailable).toBe(false);
  expect(hasPendingWithdrawal()).toBe(false);
  expect(consentPersistenceStatus()).toBe('idle');
});
