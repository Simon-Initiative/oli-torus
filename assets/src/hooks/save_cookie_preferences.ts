import {
  CONSENT_VERSION,
  consentOptions,
  hasPendingWithdrawal,
  normalizeConsent,
  saveConsent,
} from 'components/cookies/consent';

export const SaveCookiePreferences = {
  mounted() {
    this.pushEvent('browser_cookie_preferences', {
      preferences: consentOptions(),
      ...(hasPendingWithdrawal() ? { pending_withdrawal: true } : {}),
    });
    this.handleEvent('save-cookie-preferences', ({ preferences }: { preferences: unknown }) => {
      void saveConsent(normalizeConsent({ ...(preferences as object), version: CONSENT_VERSION }));
    });
  },
};
