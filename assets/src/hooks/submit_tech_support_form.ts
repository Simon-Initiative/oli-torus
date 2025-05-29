export const SubmitTechSupportForm = {
  mounted() {
    this.handleEvent('run_tech_support_hook', async (help_payload: any) => {
      if (
        typeof document.cookie == 'undefined' ||
        typeof navigator == 'undefined' ||
        !navigator.cookieEnabled
      ) {
        help_payload.cookies_enabled = 'false';
      } else {
        help_payload.cookies_enabled = 'true';
      }

      help_payload.location = window.location.href;
      help_payload.screen_size = `${screen.width} x ${screen.height}`;
      help_payload.browser_size = `${window.innerWidth} x ${window.innerHeight}`;
      help_payload.browser_plugins = getPluginsInfo();
      help_payload.operating_system = detectPlatform();
      help_payload.browser_info = getBrowserInfo();

      const grecaptcha = (window as any).grecaptcha;
      grecaptcha.reset();

      this.pushEvent('client_response', help_payload);
    });
  },
};

function detectPlatform() {
  const ua = navigator.userAgent;
  if (/Windows/i.test(ua)) return 'Windows';
  if (/Macintosh/i.test(ua)) return 'macOS';
  if (/Linux/i.test(ua)) return 'Linux';
  if (/Android/i.test(ua)) return 'Android';
  if (/iPhone|iPad|iPod/i.test(ua)) return 'iOS';
  return 'Unknown';
}

function getBrowserInfo() {
  const ua = navigator.userAgent;
  let tem;
  let match = ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\/))\/?\s*(\d+)/i) || [];

  if (/trident/i.test(match[1])) {
    tem = /\brv[ :]+(\d+)/g.exec(ua) || [];
    return 'IE ' + (tem[1] || '');
  }

  if (match[1] === 'Chrome') {
    tem = ua.match(/\b(OPR|Edge)\/(\d+)/);
    if (tem != null) {
      return tem.slice(1).join(' ').replace('OPR', 'Opera');
    }
  }

  match = match[2] ? [match[1], match[2]] : [navigator.appName, navigator.appVersion, '-?'];

  if ((tem = ua.match(/version\/(\d+)/i)) != null) {
    match.splice(1, 1, tem[1]);
  }

  return match.join(' ');
}

function getPluginsInfo(): string {
  const plugins = navigator.plugins;

  if (!plugins || plugins.length === 0) {
    return 'Plugins are not supported in this browser.';
  }

  const pluginNames = Array.from(plugins).map((plugin) => plugin.name);
  const result = pluginNames.join(', ');

  return result;
}
