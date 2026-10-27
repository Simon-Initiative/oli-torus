import {
  CONSENT_VERSION,
  normalizeConsent,
  readCookie,
  saveConsent,
} from 'components/cookies/consent';

export const SaveCookiePreferences = {
  mounted() {
    this.pushEvent('browser_cookie_preferences', {
      preferences: normalizeConsent(readCookie('_cky_opt_choices')),
    });
    this.handleEvent('save-cookie-preferences', ({ preferences }: { preferences: unknown }) => {
      void saveConsent(normalizeConsent({ ...(preferences as object), version: CONSENT_VERSION }));
    });
  },
};
