import { extractAccountLink, waitForMailboxEmail } from '@core/mailbox';
import { getBaseUrl, getScenarioToken } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { CredentialAccountPO, CredentialAccountType } from '@pom/home/CredentialAccountPO';
import { APIRequestContext, BrowserContext, Page } from '@playwright/test';

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
    baseUrl: getBaseUrl(),
    recipient: email,
    subject: 'Confirm your email',
    token: getScenarioToken(),
  });

  await account.clearSessionCookie(context);
  await account.confirm(
    extractAccountLink(
      confirmation.html_body,
      confirmation.text_body,
      account.pathSegment(),
      'confirm',
    ),
  );

  await account.login(email, initialPassword);
  await account.expectLoginSuccess();

  await account.clearSessionCookie(context);
  await account.requestPasswordReset(email);

  const reset = await waitForMailboxEmail(request, {
    baseUrl: getBaseUrl(),
    recipient: email,
    subject: 'Reset password',
    token: getScenarioToken(),
  });

  await account.resetPassword(
    extractAccountLink(reset.html_body, reset.text_body, account.pathSegment(), 'reset_password'),
    newPassword,
  );

  await account.login(email, initialPassword);
  await account.expectLoginFailure();

  await account.login(email, newPassword);
  await account.expectLoginSuccess();
}
