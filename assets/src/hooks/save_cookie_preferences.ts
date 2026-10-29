import {
  CONSENT_VERSION,
  consentOptions,
  hasPendingWithdrawal,
  initializeConsent,
  normalizeConsent,
  saveConsent,
} from 'components/cookies/consent';

/** Uses the server's authentication state when persisting mobile cookie choices. */
export const SaveCookiePreferences = {
  mounted() {
    this.pushEvent('browser_cookie_preferences', {
      preferences: consentOptions(),
      ...(hasPendingWithdrawal() ? { pending_withdrawal: true } : {}),
    });
    this.handleEvent(
      'save-cookie-preferences',
      ({ preferences, is_authenticated }: { preferences: unknown; is_authenticated?: boolean }) => {
        const chosen = normalizeConsent({ ...(preferences as object), version: CONSENT_VERSION });
        if (typeof is_authenticated === 'boolean') {
          initializeConsent(chosen, { signedIn: is_authenticated });
        }
        return saveConsent(chosen);
      },
    );
  },
};
