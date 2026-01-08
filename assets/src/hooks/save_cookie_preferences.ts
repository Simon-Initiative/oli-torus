export const SaveCookiePreferences = {
  mounted() {
    // Listen for the save-cookie-preferences event from the LiveView
    this.handleEvent('save-cookie-preferences', ({ preferences }: { preferences: any }) => {
      // Save the preferences using direct cookie implementation
      this.savePreferences(preferences);
    });
  },

  savePreferences(userOptions: any) {
    const days = 365 * 24 * 60 * 60 * 1000;

    try {
      // Set the cookies directly without relying on external utilities
      const expiration = new Date();
      expiration.setTime(expiration.getTime() + days);
      const expiresString = expiration.toUTCString();

      // Set the preference choices cookie
      this.setCookie('_cky_opt_choices', JSON.stringify(userOptions), expiresString);

      // Set the opt-in cookie
      this.setCookie('_cky_opt_in', 'true', expiresString);

      // Persist cookies to the server (optional)
      this.persistCookies([
        {
          name: '_cky_opt_choices',
          value: JSON.stringify(userOptions),
          expiresIso: expiration.toISOString(),
        },
        { name: '_cky_opt_in', value: 'true', expiresIso: expiration.toISOString() },
      ]);
    } catch (error) {
      console.error('Error saving cookie preferences:', error);
    }
  },

  setCookie(name: string, value: string, expires: string) {
    document.cookie = `${name}=${value}; expires=${expires}; path=/; SameSite=None; Secure`;
  },

  persistCookies(cookies: any[]) {
    // Send cookies to server for persistence
    fetch('/consent/cookie', {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
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
