export const SaveCookiePreferences = {
  mounted() {
    // On mount, read browser cookies and send them to the LiveView
    // This is especially important for non-authenticated users
    this.sendBrowserPreferences();

    // Listen for the save-cookie-preferences event from the LiveView
    this.handleEvent(
      'save-cookie-preferences',
      ({ preferences, is_authenticated }: { preferences: any; is_authenticated: boolean }) => {
        // Save the preferences using direct cookie implementation
        this.savePreferences(preferences, is_authenticated);
      },
    );
  },

  sendBrowserPreferences() {
    const cookieValue = this.getCookie('_cky_opt_choices');
    if (cookieValue) {
      try {
        const preferences = JSON.parse(cookieValue);
        this.pushEvent('browser_cookie_preferences', { preferences });
      } catch (e) {
        // Invalid JSON in cookie, ignore
        console.warn('Invalid cookie preferences JSON:', e);
      }
    }
  },

  getCookie(name: string): string | null {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
      return parts.pop()?.split(';').shift() || null;
    }
    return null;
  },

  savePreferences(userOptions: any, isAuthenticated: boolean) {
    const days = 365 * 24 * 60 * 60 * 1000;

    try {
      const expiration = new Date();
      expiration.setTime(expiration.getTime() + days);

      if (isAuthenticated) {
        // Authenticated users: save ONLY to database, not to browser cookies
        this.persistCookies([
          {
            name: '_cky_opt_choices',
            value: JSON.stringify(userOptions),
            expiresIso: expiration.toISOString(),
          },
          { name: '_cky_opt_in', value: 'true', expiresIso: expiration.toISOString() },
        ]);
      } else {
        // Non-authenticated users: save ONLY to browser cookies
        // These will be synced to DB on next login
        const expiresString = expiration.toUTCString();
        this.setCookie('_cky_opt_choices', JSON.stringify(userOptions), expiresString);
        this.setCookie('_cky_opt_in', 'true', expiresString);
      }
    } catch (error) {
      console.error('Error saving cookie preferences:', error);
    }
  },

  setCookie(name: string, value: string, expires: string) {
    document.cookie = `${name}=${value}; expires=${expires}; path=/; SameSite=None; Secure`;
  },

  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
  },

  persistCookies(cookies: any[]) {
    const csrfToken = this.getCsrfToken();
    // Send cookies to server for persistence
    fetch('/consent/cookie', {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(csrfToken ? { 'X-CSRF-Token': csrfToken } : {}),
      },
      body: JSON.stringify({ cookies: cookies }),
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Server responded with ${response.status}: ${response.statusText}`);
        }
        return response.json();
      })
      .catch((error) => {
        console.error('Error persisting cookies to server:', error);
        // Non-blocking error - cookies are already saved in browser
      });
  },
};
