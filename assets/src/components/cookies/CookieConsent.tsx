import React, { useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { CookiePreferencesProps } from 'components/cookies/CookiePreferences';
import {
  CONSENT_CHANGED_EVENT,
  consentOptions,
  dismissConsent,
  saveConsent,
} from 'components/cookies/consent';

const choiceClass =
  'rounded-md border border-Border-border-bold bg-Background-bg-primary px-6 py-3 font-semibold text-Text-text-button focus-visible:outline focus-visible:outline-2';

/** Offers explicit analytics choices without blocking access to the platform. */
export const CookieConsent = (props: CookiePreferencesProps & { onDismiss?: () => void }) => {
  const banner = useRef<HTMLElement>(null);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const onConsentChanged = () => props.onDismiss?.();
    window.addEventListener(CONSENT_CHANGED_EVENT, onConsentChanged);
    banner.current?.focus();
    return () => {
      window.removeEventListener(CONSENT_CHANGED_EVENT, onConsentChanged);
      if (previous?.isConnected) previous.focus();
    };
  }, [props.onDismiss]);

  const close = () => {
    dismissConsent();
    props.onDismiss?.();
  };
  const choose = (analytics: boolean) => {
    void saveConsent({ ...consentOptions(), analytics });
  };

  return (
    <section
      ref={banner}
      role="dialog"
      aria-modal="false"
      aria-labelledby="cookie-consent-heading"
      aria-describedby="cookie-consent-description"
      aria-live="polite"
      tabIndex={-1}
      className="fixed bottom-0 left-0 right-0 z-[1050] max-h-[80vh] overflow-y-auto border-t border-Border-border-bold bg-Background-bg-primary p-4 font-open-sans text-Text-text-high shadow-lg"
      onKeyDown={(event) => {
        if (event.key === 'Escape') close();
      }}
    >
      <div className="mx-auto max-w-5xl">
        <div className="flex items-start justify-between gap-4">
          <h2 id="cookie-consent-heading" className="text-lg font-bold">
            Your analytics choice
          </h2>
          <button
            type="button"
            className="rounded-md px-3 py-2 text-Text-text-button"
            aria-label="Close cookie banner"
            onClick={close}
          >
            Close
          </button>
        </div>
        <p id="cookie-consent-description">
          With your permission, we use Google Analytics cookies to understand how Torus is used and
          improve it. We measure pages visited by type, features used, and videos started or
          completed in aggregate. Analytics is off until you accept. You can change your choice in
          Cookie Preferences at any time.
        </p>
        <a
          className="font-semibold text-Text-text-button underline"
          href={props.privacyPoliciesUrl}
        >
          Privacy Notice
        </a>
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <button type="button" className={choiceClass} onClick={() => choose(true)}>
            Accept
          </button>
          <button type="button" className={choiceClass} onClick={() => choose(false)}>
            Reject
          </button>
          <a
            href="/cookie-preferences"
            className="rounded-md px-3 py-3 font-semibold text-Text-text-button underline"
            onClick={(event) => {
              if (!props.isMobileOrTablet && (window as any).OLI?.handleCookiePreferences) {
                event.preventDefault();
                close();
                (window as any).OLI.handleCookiePreferences(props.privacyPoliciesUrl);
              }
            }}
          >
            Manage preferences
          </a>
        </div>
      </div>
    </section>
  );
};

export function selectCookieConsent(props: CookiePreferencesProps): void {
  let container = document.querySelector('#cookie_consent_display');
  if (!container) {
    container = document.createElement('div');
    container.id = 'cookie_consent_display';
    document.body.appendChild(container);
  }
  const target = container;
  ReactDOM.render(
    <CookieConsent {...props} onDismiss={() => ReactDOM.unmountComponentAtNode(target)} />,
    target,
  );
}
