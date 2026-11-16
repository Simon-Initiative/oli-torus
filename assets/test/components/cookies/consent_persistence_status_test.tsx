/** @jest-environment-options {"url":"https://torus.example.test/courses/lesson"} */
import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { ConsentPersistenceStatus } from '../../../src/components/cookies/ConsentPersistenceStatus';
import { CookieConsent } from '../../../src/components/cookies/CookieConsent';
import {
  consentOptions,
  initializeConsent,
  readCookie,
  saveConsent,
} from '../../../src/components/cookies/consent';

beforeEach(() => {
  delete window.TorusConsentState;
  sessionStorage.clear();
  document.cookie.split(';').forEach((cookie) => {
    document.cookie = `${cookie.split('=')[0].trim()}=;max-age=0;path=/;Secure`;
  });
  window.gtag = jest.fn();
  initializeConsent(
    { version: 2, functionality: true, analytics: true },
    { signedIn: true, measurementAvailable: true, measurementIds: ['G-ABC123'] },
  );
});

afterEach(() => {
  jest.restoreAllMocks();
});

test('failed persistence remains visible while retrying and disappears after acknowledgement', async () => {
  let acknowledgeRetry: (response: unknown) => void = () => undefined;
  global.fetch = jest
    .fn()
    .mockResolvedValueOnce({ ok: false, status: 503 })
    .mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          acknowledgeRetry = resolve;
        }),
    );
  render(<ConsentPersistenceStatus />);
  expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  expect(screen.queryByRole('status')).not.toBeInTheDocument();

  await act(async () => {
    await saveConsent({ functionality: true, analytics: false });
  });
  expect(screen.getByRole('alert')).toHaveTextContent('could not be saved');
  expect(screen.getByRole('button', { name: 'Retry' })).toBeEnabled();

  fireEvent.click(screen.getByRole('button', { name: 'Retry' }));
  expect(screen.getByRole('status')).toHaveTextContent('Saving cookie preferences');
  expect(screen.getByRole('button', { name: 'Retrying…' })).toBeDisabled();
  expect(consentOptions().analytics).toBe(false);

  const request = JSON.parse((fetch as jest.Mock).mock.calls[1][1].body);
  await act(async () => {
    acknowledgeRetry({
      ok: true,
      json: async () => ({
        result: 'success',
        persistence: 'persisted',
        decision: request.decision,
        acknowledged: true,
      }),
    });
  });
  expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  expect(screen.queryByRole('status')).not.toBeInTheDocument();
  expect(readCookie('_cky_pending_consent')).toBe('');
});

test('the shared failure status survives a consent banner closing after a choice', async () => {
  global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 403 });
  render(<ConsentPersistenceStatus />);
  const banner = render(
    <CookieConsent privacyPoliciesUrl="/privacy" onDismiss={() => banner.unmount()} />,
  );

  await act(async () => {
    fireEvent.click(screen.getByRole('button', { name: 'Reject' }));
  });

  expect(screen.queryByRole('dialog', { name: 'Your analytics choice' })).not.toBeInTheDocument();
  expect(screen.getByRole('alert')).toHaveTextContent('could not be saved');
  expect(screen.getByRole('button', { name: 'Retry' })).toBeEnabled();
  expect(consentOptions().analytics).toBe(false);
});
