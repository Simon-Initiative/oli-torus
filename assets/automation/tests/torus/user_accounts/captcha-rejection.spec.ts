import { configureCaptcha } from '@core/captcha';
import { expect, test } from '@playwright/test';

test.describe('registration captcha authorization @pr', () => {
  for (const type of ['user', 'author']) {
    for (const credential of ['missing', 'incorrect']) {
      test(`${type} registration rejects a ${credential} credential`, async ({
        context,
        page,
        baseURL,
      }) => {
        await configureCaptcha(
          context,
          baseURL!,
          credential === 'missing' ? '' : 'incorrect-token',
        );
        await page.goto(`/${type}s/register`);
        await expect(page.locator('[data-phx-main].phx-connected')).toBeAttached();

        const form = page.locator('#registration_form');
        const fields = {
          email: `captcha-${type}-${credential}-${Date.now()}@example.test`,
          given_name: 'Captcha',
          family_name: 'Rejection',
          password: 'Valid-password-123!',
          password_confirmation: 'Valid-password-123!',
        };
        for (const [name, value] of Object.entries(fields)) {
          await form.locator(`input[name="${type}[${name}]"]`).fill(value);
        }
        const acceptCookies = page
          .locator('#cookie_consent_display')
          .getByRole('button', { name: 'Accept', exact: true });
        await acceptCookies.click();
        await expect(acceptCookies).toBeHidden();
        await form.getByRole('button', { name: 'Create account', exact: true }).click();
        await expect(form.getByText('reCAPTCHA failed, please try again')).toBeVisible();
        await expect(page).toHaveURL(new RegExp(`/${type}s/register$`));
      });
    }
  }
});
