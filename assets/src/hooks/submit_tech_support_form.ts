export const SubmitTechSupportForm = {
  mounted() {
    this.handleEvent('run_tech_support_hook', async (payload: any) => {
      payload.help = payload.help || {};
      if (
        typeof document.cookie == 'undefined' ||
        typeof navigator == 'undefined' ||
        !navigator.cookieEnabled
      ) {
        payload.help.cookies_enabled = 'false';
      } else {
        payload.help.cookies_enabled = 'true';
      }

      payload.help.location = window.location.href;
      payload.help.screen_size = `${screen.width} x ${screen.height}`;
      payload.help.browser_size = `${window.innerWidth} x ${window.innerHeight}`;
      payload.help.browser_plugins = getPluginsInfo();
      payload.help.operating_system = detectPlatform();
      payload.help.browser_info = getBrowserInfo();

      const grecaptcha = (window as any).grecaptcha;
      grecaptcha.reset();

      try {
        const res = await fetch('/help/create', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify(payload),
        });

        const json = await res.json();
        this.pushEvent('form_response', json);
      } catch (err) {
        console.log('Something went wrong when trying to request help', err);
        this.pushEvent('form_response', { error: err });
      }
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
