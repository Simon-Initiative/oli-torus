import { configureCaptcha } from '@core/captcha';
import { expect, test } from '@playwright/test';

const origin = 'http://torus.test';
const token = 'fixture-only-captcha-token';
const field = 'g-recaptcha-response';

test.describe('captcha submission boundary @pr', () => {
  test.beforeEach(async ({ context, page }) => {
    await configureCaptcha(context, origin, token);
    await page.route('http://torus.test/**', (route) =>
      route.fulfill({
        contentType: 'text/html',
        body: '<form id="protected" method="post" action="/submit"><div class="g-recaptcha"></div><input name="email" value="test@example.test"><button>Submit</button></form>',
      }),
    );
    await page.goto(origin);
  });

  test('native POST carries the token without adding a field', async ({ page }) => {
    await expect(page.locator(`[name="${field}"]`)).toHaveCount(0);
    const request = page.waitForRequest((request) => request.method() === 'POST');
    await page.getByRole('button').click();
    expect(new URLSearchParams((await request).postData()!).get(field)).toBe(token);
  });

  test('LiveView FormData includes one token after form replacement without changing the DOM', async ({
    page,
  }) => {
    const result = await page.evaluate(() => {
      document.querySelector('form')!.outerHTML =
        '<form phx-submit="save"><div phx-hook="Recaptcha"></div><input name="g-recaptcha-response" value="stale"></form>';
      const form = document.querySelector('form')!;
      const before = form.outerHTML;
      const data = new FormData(form);
      return {
        values: data.getAll('g-recaptcha-response'),
        unchanged: before === form.outerHTML,
        nativeInstance: data instanceof FormData,
      };
    });
    expect(result).toEqual({ values: [token], unchanged: true, nativeInstance: true });
  });

  for (const submission of ['requestSubmit', 'submit'] as const) {
    test(`native GET on a LiveView form never receives a token via ${submission}`, async ({
      page,
    }) => {
      const request = page.waitForRequest(
        (request) => new URL(request.url()).pathname === '/submit',
      );
      await page.locator('form').evaluate((form: HTMLFormElement, submission) => {
        form.removeAttribute('method');
        form.setAttribute('phx-submit', 'save');
        form[submission]();
      }, submission);
      expect(new URL((await request).url()).searchParams.has(field)).toBe(false);
    });
  }

  for (const attributes of [
    'type="submit" formaction="https://external.test/"',
    'type="submit" formmethod="get"',
    'type="image" formaction="https://external.test/"',
    'type="image" formmethod="get"',
  ]) {
    test(`withholds the token for an external submit control with ${attributes}`, async ({
      page,
    }) => {
      const values = await page.evaluate((attributes) => {
        document.body.insertAdjacentHTML(
          'beforeend',
          `<input value="Override" alt="Override" form="protected" ${attributes}>`,
        );
        const form = document.querySelector('form')!;
        form.setAttribute('phx-submit', 'save');
        return new FormData(form).getAll('g-recaptcha-response');
      }, attributes);
      expect(values).toEqual([]);
      const request = page.waitForRequest((request) => request.isNavigationRequest());
      await page.route('https://external.test/**', (route) => route.fulfill({ body: 'external' }));
      await page.locator('input[form="protected"]').click();
      const submitted = await request;
      expect(submitted.url()).not.toContain(token);
      expect(submitted.postData() || '').not.toContain(token);
    });
  }

  test('withholds the token from external actions, unprotected forms and external frames', async ({
    page,
  }) => {
    const values = await page.evaluate(() => {
      const form = document.querySelector('form')!;
      form.action = 'https://external.test/';
      const external = new FormData(form).get('g-recaptcha-response');
      form.action = '/submit';
      form.querySelector('.g-recaptcha')!.remove();
      return [external, new FormData(form).get('g-recaptcha-response')];
    });
    expect(values).toEqual([null, null]);
    await page.route('https://external.test/**', (route) =>
      route.fulfill({
        contentType: 'text/html',
        body: `<form method="post" action="${origin}/submit" phx-submit="save"><div class="g-recaptcha"></div></form>`,
      }),
    );
    await page.evaluate(() => {
      const frame = document.createElement('iframe');
      frame.src = 'https://external.test/';
      document.body.append(frame);
    });
    const form = page.frameLocator('iframe').locator('form');
    await expect(form).toBeAttached();
    expect(
      await form.evaluate((form: HTMLFormElement) =>
        new FormData(form).get('g-recaptcha-response'),
      ),
    ).toBeNull();
  });

  test('blocks Google script loading', async ({ page }) => {
    const failed = page.waitForEvent('requestfailed', (request) =>
      request.url().startsWith('https://www.google.com/recaptcha/'),
    );
    await page.evaluate(() => {
      const script = document.createElement('script');
      script.src = 'https://www.google.com/recaptcha/api.js';
      document.head.append(script);
    });
    await failed;
  });
});
