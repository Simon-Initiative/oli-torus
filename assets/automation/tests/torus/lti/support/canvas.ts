import { type Page } from '@playwright/test';

// Logs into Canvas with the given credentials and waits for the successful-login redirect.
export const loginToCanvas = async (page: Page, email: string, password: string) => {
  await page.goto('https://canvas.oli.cmu.edu/login/canvas');
  await page.getByRole('textbox', { name: 'Email' }).fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await Promise.all([
    page.waitForURL('https://canvas.oli.cmu.edu/?login_success=1'),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);
};
