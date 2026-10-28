/** @jest-environment-options {"url":"https://torus.example.test/courses/lesson"} */
import React from 'react';
import ReactDOM from 'react-dom';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { CookieConsent } from '../../../src/components/cookies/CookieConsent';
import {
  CookiePreferences,
  selectCookiePreferences,
} from '../../../src/components/cookies/CookiePreferences';
import {
  CONSENT_CHANGED_EVENT,
  consentOptions,
  hasCurrentDecision,
  initializeConsent,
  isConsentDismissed,
  normalizeConsent,
  readCookie,
  saveConsent,
} from '../../../src/components/cookies/consent';
import { retrieveCookies } from '../../../src/components/cookies/utils';
import { SaveCookiePreferences } from '../../../src/hooks/save_cookie_preferences';

const accepted = {
  necessary: true,
  functionality: false,
  analytics: true,
  targeting: false,
  version: 2,
};

beforeEach(() => {
  delete window.TorusConsentState;
  Object.keys(window)
    .filter((key) => key.startsWith('ga-disable-G-'))
    .forEach((key) => delete (window as unknown as Record<string, unknown>)[key]);
  document.cookie.split(';').forEach((cookie) => {
    document.cookie = `${cookie.split('=')[0].trim()}=;max-age=0;path=/;Secure`;
    document.cookie = `${cookie.split('=')[0].trim()}=;max-age=0;path=/;domain=example.test;Secure`;
  });
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
  window.gtag = jest.fn();
  global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ result: 'no-op' }) });
});

afterEach(() => {
  jest.restoreAllMocks();
  for (const id of ['cookie_consent_display', 'cookie_prefs_display']) {
    const container = document.getElementById(id);
    if (container) {
      ReactDOM.unmountComponentAtNode(container);
      container.remove();
    }
  }
});

test.each([
  undefined,
  null,
  '{}',
  '{broken',
  [],
  { version: 2, analytics: 'true' },
  { version: 1, analytics: true },
])('undecided or malformed preferences deny analytics: %p', (value) => {
  expect(normalizeConsent(value).analytics).toBe(false);
  expect(normalizeConsent(value).version).toBeUndefined();
});

test('old consent preserves functionality and re-prompts despite legacy opt-in/dismiss flags', async () => {
  document.cookie = `_cky_opt_choices=${encodeURIComponent(
    JSON.stringify({ ...accepted, version: 1 }),
  )};path=/;Secure`;
  document.cookie = '_cky_opt_in=true;path=/;Secure';
  document.cookie = '_cky_opt_in_dismiss=true;path=/;Secure';
  expect(consentOptions()).toMatchObject({ functionality: false, analytics: false });
  expect(hasCurrentDecision()).toBe(false);
  await act(async () => {
    await retrieveCookies('/consent/cookie', { privacyPoliciesUrl: '/privacy' });
  });
  expect(screen.getByRole('button', { name: 'Reject' })).toBeVisible();
});

test('server state is authoritative and cannot overwrite a later same-page choice', async () => {
  initializeConsent(accepted);
  expect(consentOptions().analytics).toBe(true);
  await saveConsent({ functionality: true, analytics: false });
  initializeConsent(accepted);
  expect(consentOptions()).toMatchObject({ functionality: true, analytics: false, version: 2 });
});

test.each([true, false])(
  'explicit analytics=%p writes a versioned 365-day cookie and persists with CSRF',
  async (analytics) => {
    const cookieSetter = jest.spyOn(Document.prototype, 'cookie', 'set');
    document.cookie = '_cky_opt_in_dismiss=2;path=/;Secure';
    const changed = jest.fn();
    window.addEventListener(CONSENT_CHANGED_EVENT, changed);
    await saveConsent({ functionality: false, analytics });
    window.removeEventListener(CONSENT_CHANGED_EVENT, changed);
    expect(JSON.parse(readCookie('_cky_opt_choices'))).toEqual({ ...accepted, analytics });
    expect(hasCurrentDecision()).toBe(true);
    expect(readCookie('_cky_opt_in_dismiss')).toBe('');
    expect(window.gtag).toHaveBeenCalledWith('consent', 'update', {
      analytics_storage: analytics ? 'granted' : 'denied',
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
    });
    expect(fetch).toHaveBeenCalledWith(
      '/consent/cookie',
      expect.objectContaining({
        credentials: 'same-origin',
        headers: expect.objectContaining({ 'X-CSRF-Token': 'csrf-value' }),
      }),
    );
    const written = cookieSetter.mock.calls.find(([cookie]) =>
      cookie.startsWith('_cky_opt_choices='),
    )![0];
    const expiry = new Date(written.split('expires=')[1]);
    expect(expiry.getTime() - Date.now()).toBeGreaterThan(364 * 24 * 60 * 60 * 1000);
    expect(written).toContain('SameSite=None;Secure');
    expect(changed).toHaveBeenCalledTimes(1);
  },
);

test('withdrawal removes Torus-host GA cookies, preserves parent-domain cookies and disables GA', async () => {
  document.cookie = '_ga=parent-client;domain=example.test;path=/;Secure';
  document.cookie = '_ga_other=parent-session;domain=example.test;path=/;Secure';
  document.cookie = '_ga=host-client;path=/;Secure';
  document.cookie = '_ga_ABC123=host-session;domain=torus.example.test;path=/;Secure';
  document.cookie = 'unrelated=keep;path=/;Secure';
  await saveConsent({ functionality: true, analytics: false });
  expect(
    document.cookie
      .split(';')
      .map((cookie) => cookie.trim())
      .filter((cookie) => cookie.startsWith('_ga=')),
  ).toEqual(['_ga=parent-client']);
  expect(readCookie('_ga_ABC123')).toBe('');
  expect(readCookie('_ga_other')).toBe('parent-session');
  expect(readCookie('unrelated')).toBe('keep');
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(true);
  await saveConsent({ functionality: true, analytics: true });
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(false);
});

test('malformed percent-encoding is ignored', () => {
  document.cookie = '_cky_opt_choices=%broken;path=/;Secure';
  expect(consentOptions().analytics).toBe(false);
});

test('banner provides equal Accept/Reject controls, names Google Analytics, and restores focus on close', () => {
  const trigger = document.createElement('button');
  document.body.appendChild(trigger);
  trigger.focus();
  const dismiss = jest.fn();
  const view = render(<CookieConsent privacyPoliciesUrl="/privacy" onDismiss={dismiss} />);
  expect(screen.getByRole('dialog')).toHaveFocus();
  expect(screen.getByRole('button', { name: 'Accept' }).className).toBe(
    screen.getByRole('button', { name: 'Reject' }).className,
  );
  expect(screen.getByText(/we use Google Analytics cookies/)).toBeVisible();
  expect(screen.getByRole('link', { name: 'Privacy Notice' })).toHaveAttribute('href', '/privacy');
  fireEvent.click(screen.getByRole('button', { name: 'Close cookie banner' }));
  expect(dismiss).toHaveBeenCalled();
  expect(isConsentDismissed()).toBe(true);
  expect(hasCurrentDecision()).toBe(false);
  expect(window.gtag).not.toHaveBeenCalled();
  view.unmount();
  expect(trigger).toHaveFocus();
  trigger.remove();
});

test.each(['Accept', 'Reject'])('banner %s explicitly stores the decision', (name) => {
  const dismiss = jest.fn();
  render(<CookieConsent privacyPoliciesUrl="/privacy" onDismiss={dismiss} />);
  fireEvent.click(screen.getByRole('button', { name }));
  expect(consentOptions().analytics).toBe(name === 'Accept');
  expect(hasCurrentDecision()).toBe(true);
  expect(dismiss).toHaveBeenCalled();
});

test('Manage then Cancel keeps the banner undecided and returns focus without dismissing consent', () => {
  const previousOLI = window.OLI;
  const previousJQuery = window.$;
  window.$ = ((element: HTMLElement) => ({
    modal: (action: string) => {
      element.style.display = action === 'show' ? 'block' : 'none';
    },
    on: (name: string, handler: EventListener) => element.addEventListener(name, handler),
  })) as unknown as typeof window.$;
  window.OLI = {
    ...previousOLI,
    handleCookiePreferences: (privacyPoliciesUrl: string) =>
      selectCookiePreferences({ privacyPoliciesUrl }),
  };

  try {
    const dismiss = jest.fn();
    render(<CookieConsent privacyPoliciesUrl="/privacy" onDismiss={dismiss} />);
    const manage = screen.getByRole('link', { name: 'Manage preferences' });
    manage.focus();
    fireEvent.click(manage);

    const modal = screen.getByRole('dialog', { name: 'Cookie Preferences' });
    fireEvent(modal, new Event('shown.bs.modal'));
    expect(modal.contains(document.activeElement)).toBe(true);
    expect(screen.getByRole('dialog', { name: 'Your analytics choice' })).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Cancel' }));
    fireEvent(modal, new Event('hidden.bs.modal'));

    expect(screen.queryByRole('dialog', { name: 'Cookie Preferences' })).not.toBeInTheDocument();
    expect(screen.getByRole('dialog', { name: 'Your analytics choice' })).toBeVisible();
    expect(manage).toHaveFocus();
    expect(isConsentDismissed()).toBe(false);
    expect(hasCurrentDecision()).toBe(false);
    expect(consentOptions().analytics).toBe(false);
    expect(window.gtag).not.toHaveBeenCalled();
    expect(dismiss).not.toHaveBeenCalled();
  } finally {
    const preferences = document.getElementById('cookie_prefs_display');
    if (preferences) {
      ReactDOM.unmountComponentAtNode(preferences);
      preferences.remove();
    }
    window.OLI = previousOLI;
    window.$ = previousJQuery;
  }
});

test('preferences start analytics off, disclose actual cookies, and do not leak an unsaved draft', () => {
  const view = render(<CookiePreferences privacyPoliciesUrl="/privacy" />);
  expect(screen.getByRole('switch', { name: 'Analytics Cookies' })).not.toBeChecked();
  expect(screen.queryByRole('switch', { name: 'Targeting Cookies' })).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole('switch', { name: 'Analytics Cookies' }));
  expect(consentOptions().analytics).toBe(false);
  view.unmount();
  render(<CookiePreferences privacyPoliciesUrl="/privacy" />);
  expect(screen.getByRole('switch', { name: 'Analytics Cookies' })).not.toBeChecked();
  fireEvent.click(screen.getByRole('button', { name: 'Analytics Cookies' }));
  expect(screen.getByText('_ga, _ga_<measurement-id>')).toBeInTheDocument();
  expect(screen.getAllByText('torus.example.test').length).toBe(2);
});

test('mobile hook uses the same browser and server persistence path for signed-in choices', async () => {
  document.cookie = `_cky_opt_choices=${encodeURIComponent(
    JSON.stringify({ ...accepted, version: 1 }),
  )};path=/;Secure`;
  const hook = { pushEvent: jest.fn(), handleEvent: jest.fn() };
  SaveCookiePreferences.mounted.call(hook);
  expect(hook.pushEvent).toHaveBeenCalledWith('browser_cookie_preferences', {
    preferences: expect.objectContaining({ functionality: false, analytics: false }),
  });
  const save = hook.handleEvent.mock.calls[0][1];
  await act(async () => {
    save({ preferences: accepted, is_authenticated: true });
  });
  expect(JSON.parse(readCookie('_cky_opt_choices'))).toEqual(accepted);
  expect(fetch).toHaveBeenCalledWith(
    '/consent/cookie',
    expect.objectContaining({ method: 'POST' }),
  );
  expect(window.gtag).toHaveBeenCalled();
});

test.each(['', '   '])(
  'blank privacy notice %p does not show the banner',
  async (privacyPoliciesUrl) => {
    await retrieveCookies('/consent/cookie', { privacyPoliciesUrl, preferences: {} });
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  },
);

test('overlapping choices start keepalive requests immediately with increasing per-document order', async () => {
  let finishFirst: (value: unknown) => void = () => undefined;
  (fetch as jest.Mock).mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finishFirst = resolve;
      }),
  );
  const firstSave = saveConsent({ functionality: true, analytics: true });
  const secondSave = saveConsent({ functionality: true, analytics: false });
  expect(consentOptions().analytics).toBe(false);
  expect(fetch).toHaveBeenCalledTimes(2);
  const bodies = (fetch as jest.Mock).mock.calls.map(([, options]) => JSON.parse(options.body));
  expect(JSON.parse(bodies[0].cookies[0].value).analytics).toBe(true);
  expect(JSON.parse(bodies[1].cookies[0].value).analytics).toBe(false);
  expect(bodies[0].decision.group).toMatch(/^[a-f0-9]{32}$/);
  expect(bodies[1].decision).toEqual({ group: bodies[0].decision.group, sequence: 2 });
  expect(bodies[0].decision.sequence).toBe(1);
  expect(readCookie('_cky_opt_choices')).not.toContain(bodies[0].decision.group);
  for (const [, options] of (fetch as jest.Mock).mock.calls) {
    expect(options.keepalive).toBe(true);
  }
  await secondSave;
  finishFirst({ ok: true });
  await firstSave;
  expect(consentOptions().analytics).toBe(false);
});

test('blank policy availability keeps Google denied even for an explicitly stored acceptance', async () => {
  initializeConsent({}, { measurementAvailable: false });
  document.cookie = '_ga_ABC123=session;path=/;Secure';
  await saveConsent({ functionality: true, analytics: true });
  expect(consentOptions().analytics).toBe(true);
  expect(window.gtag).toHaveBeenCalledWith(
    'consent',
    'update',
    expect.objectContaining({ analytics_storage: 'denied' }),
  );
  expect(readCookie('_ga_ABC123')).toBe('');
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(true);
});

test('a valid privacy URL cannot enable measurement disabled by analytics configuration', async () => {
  initializeConsent(accepted, { measurementAvailable: false, measurementIds: ['G-ABC123'] });
  await retrieveCookies('/consent/cookie', {
    privacyPoliciesUrl: '/privacy',
    preferences: accepted,
  });
  await saveConsent({ functionality: true, analytics: true });

  expect(window.TorusConsentState?.measurementAvailable).toBe(false);
  expect(window.gtag).toHaveBeenCalledWith(
    'consent',
    'update',
    expect.objectContaining({ analytics_storage: 'denied' }),
  );
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(true);
});

test('configured measurement IDs disable collection after withdrawal even when GA cookies are absent', async () => {
  initializeConsent(accepted, { measurementAvailable: true, measurementIds: ['G-ABC123'] });
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(false);
  await saveConsent({ functionality: true, analytics: false });
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(true);
  await saveConsent({ functionality: true, analytics: true });
  expect((window as unknown as Record<string, unknown>)['ga-disable-G-ABC123']).toBe(false);
});
