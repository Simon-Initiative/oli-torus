import { extractAccountLink, waitForMailboxEmail } from '@core/mailbox';
import { test } from '@fixture/my-fixture';
import { CredentialAccountPO, CredentialAccountType } from '@pom/home/CredentialAccountPO';
import { APIRequestContext, BrowserContext, Page } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const scenarioToken = process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token';

test.describe('credential-based account flows @pr', () => {
  test.describe.configure({ timeout: 120_000 });

  test('author self-service lifecycle', async ({ context, page, request }, testInfo) => {
    await exerciseSelfServiceLifecycle('author', context, page, request, testInfo.parallelIndex);
  });

  test('independent learner self-service lifecycle', async ({
    context,
    page,
    request,
  }, testInfo) => {
    await exerciseSelfServiceLifecycle('user', context, page, request, testInfo.parallelIndex);
  });
});

async function exerciseSelfServiceLifecycle(
  type: CredentialAccountType,
  context: BrowserContext,
  page: Page,
  request: APIRequestContext,
  parallelIndex: number,
) {
  const suffix = `${Date.now()}-${parallelIndex}-${type}`;
  const email = `pw-${suffix}@example.test`;
  const initialPassword = `Initial-${suffix}-password`;
  const newPassword = `Reset-${suffix}-password`;
  const account = new CredentialAccountPO(page, type);

  await account.register({
    email,
    givenName: 'Playwright',
    familyName: type === 'author' ? 'Author' : 'Learner',
    password: initialPassword,
  });

  const confirmation = await waitForMailboxEmail(request, {
    baseUrl,
    recipient: email,
    subject: 'Confirm your email',
    token: scenarioToken,
  });

  // Clear only the session cookie so the confirmation/reset links are followed
  // anonymously, without wiping the cookie-consent choice and re-triggering
  // the consent modal on the next navigation.
  await context.clearCookies({ name: '_oli_key' });
  await account.confirm(
    extractAccountLink(confirmation.html_body, confirmation.text_body, segment(type), 'confirm'),
  );

  await account.login(email, initialPassword);
  await account.expectLoginSuccess();

  // Clear only the session cookie so the confirmation/reset links are followed
  // anonymously, without wiping the cookie-consent choice and re-triggering
  // the consent modal on the next navigation.
  await context.clearCookies({ name: '_oli_key' });
  await account.requestPasswordReset(email);

  const reset = await waitForMailboxEmail(request, {
    baseUrl,
    recipient: email,
    subject: 'Reset password',
    token: scenarioToken,
  });

  await account.resetPassword(
    extractAccountLink(reset.html_body, reset.text_body, segment(type), 'reset_password'),
    newPassword,
  );

  await account.login(email, initialPassword);
  await account.expectLoginFailure();

  await account.login(email, newPassword);
  await account.expectLoginSuccess();
}

function segment(type: CredentialAccountType): 'authors' | 'users' {
  return type === 'author' ? 'authors' : 'users';
}
