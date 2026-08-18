import { waitForMailboxEmail } from '@core/mailbox';
import { test } from '@fixture/my-fixture';
import { CredentialAccountPO, CredentialAccountType } from '@pom/home/CredentialAccountPO';
import { APIRequestContext, BrowserContext, Page } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const scenarioToken = process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token';

test.describe('credential-based account flows', () => {
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

  await setCookieConsent(context);
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

  await context.clearCookies();
  await setCookieConsent(context);
  await account.confirm(
    extractAccountLink(confirmation.html_body, confirmation.text_body, type, 'confirm'),
  );

  await account.login(email, initialPassword);
  await account.expectLoginSuccess();

  await context.clearCookies();
  await setCookieConsent(context);
  await account.requestPasswordReset(email);

  const reset = await waitForMailboxEmail(request, {
    baseUrl,
    recipient: email,
    subject: 'Reset password',
    token: scenarioToken,
  });

  await account.resetPassword(
    extractAccountLink(reset.html_body, reset.text_body, type, 'reset_password'),
    newPassword,
  );

  await account.login(email, initialPassword);
  await account.expectLoginFailure();

  await account.login(email, newPassword);
  await account.expectLoginSuccess();
}

function setCookieConsent(context: BrowserContext) {
  return context.addCookies([
    {
      name: '_cky_opt_in',
      value: 'true',
      url: baseUrl,
    },
  ]);
}

function extractAccountLink(
  htmlBody: string | null,
  textBody: string | null,
  type: CredentialAccountType,
  action: 'confirm' | 'reset_password',
) {
  const segment = type === 'author' ? 'authors' : 'users';
  const path = `/${segment}/${action}/`;
  const source = [htmlBody, textBody].filter(Boolean).join(' ');
  const match = source.match(new RegExp(`https?:\\/\\/[^\\s"'<]+${path}[^\\s"'<]+`));

  if (!match) {
    throw new Error(`Expected an account ${action} URL for ${type} in the email.`);
  }

  return match[0].replace(/&amp;/g, '&');
}
