import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import {
  CONSENT_PERSISTENCE_EVENT,
  consentPersistenceStatus,
  retryConsent,
} from 'components/cookies/consent';

/** Keeps failed cookie-preference saves recoverable after any consent UI closes. */
export const ConsentPersistenceStatus = () => {
  const [status, setStatus] = useState(consentPersistenceStatus);
  const [visible, setVisible] = useState(() => consentPersistenceStatus() === 'failed');

  useEffect(() => {
    const update = () => {
      const next = consentPersistenceStatus();
      setStatus(next);
      if (next === 'failed') setVisible(true);
      if (next === 'idle') setVisible(false);
    };
    window.addEventListener(CONSENT_PERSISTENCE_EVENT, update);
    update();
    return () => window.removeEventListener(CONSENT_PERSISTENCE_EVENT, update);
  }, []);

  if (!visible) return null;

  const saving = status === 'saving';
  return (
    <div
      role={saving ? 'status' : 'alert'}
      aria-busy={saving}
      className="fixed bottom-4 right-4 z-[2060] mx-4 max-w-sm rounded-md border border-Border-border-bold bg-Background-bg-primary p-4 font-open-sans text-Text-text-high shadow-lg"
    >
      <p>
        {saving
          ? 'Saving cookie preferences…'
          : 'Your cookie preferences could not be saved. Please retry.'}
      </p>
      <button
        type="button"
        disabled={saving}
        onClick={() => void retryConsent()}
        className="mt-3 rounded-md border border-Border-border-bold px-4 py-2 font-semibold text-Text-text-button focus-visible:outline focus-visible:outline-2 disabled:opacity-50"
      >
        {saving ? 'Retrying…' : 'Retry'}
      </button>
    </div>
  );
};

/** Mounts one shared save-status surface for the banner, modal, and mobile preferences. */
export function mountConsentPersistenceStatus(): void {
  let container = document.getElementById('cookie_consent_persistence_status');
  if (!container) {
    container = document.createElement('div');
    container.id = 'cookie_consent_persistence_status';
    document.body.appendChild(container);
  }
  ReactDOM.render(<ConsentPersistenceStatus />, container);
}
