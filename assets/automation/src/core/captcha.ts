import { type BrowserContext } from '@playwright/test';

/**
 * Supply the private automation credential without changing captcha markup or
 * deploying a client substitute. Call before creating pages in custom contexts.
 */
export async function configureCaptcha(
  context: BrowserContext,
  baseUrl: string,
  token = process.env.PLAYWRIGHT_CAPTCHA_TOKEN,
): Promise<void> {
  await context.route(
    (url) =>
      ['www.google.com', 'www.recaptcha.net', 'www.gstatic.com'].includes(url.hostname) &&
      url.pathname.startsWith('/recaptcha/'),
    (route) => route.abort(),
  );

  if (!token) return;

  await context.addInitScript(
    ({ origin, token }) => {
      if (location.origin !== origin) return;

      const eligible = (form: HTMLFormElement): boolean => {
        if (
          !form.querySelector('.g-recaptcha, [phx-hook="Recaptcha"]') ||
          new URL(form.action).origin !== origin
        ) {
          return false;
        }

        // FormDataEvent has no submitter. Reject unsafe overrides on any
        // associated control, including external controls and image submitters
        // (which browsers omit from form.elements).
        return Array.from(document.querySelectorAll('button, input')).every((control) => {
          if (
            !(control instanceof HTMLButtonElement || control instanceof HTMLInputElement) ||
            control.form !== form
          ) {
            return true;
          }
          return (
            (!control.hasAttribute('formaction') ||
              new URL(control.formAction).origin === origin) &&
            (!control.hasAttribute('formmethod') || control.formMethod === 'post')
          );
        });
      };

      document.addEventListener(
        'formdata',
        (event) => {
          const form = event.target;
          if (form instanceof HTMLFormElement && form.method === 'post' && eligible(form)) {
            event.formData.set('g-recaptcha-response', token);
          }
        },
        true,
      );

      // LiveView serializes with new FormData(form). Actionless LiveView forms
      // default to GET: add the token only to the JS result, never to native GET
      // submission (including form.submit(), which bypasses submit listeners).
      window.FormData = new Proxy(window.FormData, {
        construct(target, args, newTarget) {
          const data = Reflect.construct(target, args, newTarget) as FormData;
          const [form] = args;
          if (
            form instanceof HTMLFormElement &&
            form.hasAttribute('phx-submit') &&
            eligible(form)
          ) {
            data.set('g-recaptcha-response', token);
          }
          return data;
        },
      });
    },
    { origin: new URL(baseUrl).origin, token },
  );
}
