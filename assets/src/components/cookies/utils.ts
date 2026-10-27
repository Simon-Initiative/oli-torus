import { selectCookieConsent } from 'components/cookies/CookieConsent';
import { CookiePreferencesProps } from 'components/cookies/CookiePreferences';
import {
  consentOptions,
  hasCurrentDecision,
  initializeConsent,
  isConsentDismissed,
} from 'components/cookies/consent';

export { consentOptions } from 'components/cookies/consent';

/** Initializes consent from the page's server decision and offers a nonblocking choice when needed. */
export const retrieveCookies = async (url: string, props: CookiePreferencesProps) => {
  const privacyPoliciesUrl =
    typeof props.privacyPoliciesUrl === 'string' ? props.privacyPoliciesUrl.trim() : '';
  if (props.preferences !== undefined) {
    initializeConsent(props.preferences);
  } else if (!window.TorusConsentState?.initialized) {
    try {
      const response = await fetch(url, {
        credentials: 'same-origin',
        headers: { Accept: 'application/json' },
      });
      const cookies = await response.json();
      if (Array.isArray(cookies)) {
        const choice = cookies.find(
          (cookie) =>
            cookie.name === '_cky_opt_choices' && new Date(cookie.expiration) > new Date(),
        );
        initializeConsent(choice?.value ?? consentOptions());
      }
    } catch {
      // Browser choices remain usable when the server cannot be reached.
    }
  }
  if (privacyPoliciesUrl && !hasCurrentDecision() && !isConsentDismissed()) {
    selectCookieConsent({ ...props, privacyPoliciesUrl });
  }
};
