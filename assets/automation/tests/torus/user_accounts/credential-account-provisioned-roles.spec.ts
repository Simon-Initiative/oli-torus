import path from 'node:path';
import { extractAccountLink, waitForMailboxEmail } from '@core/mailbox';
import { getBaseUrl, getScenarioToken } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { CredentialAccountPO, CredentialAccountType } from '@pom/home/CredentialAccountPO';
import { APIRequestContext, BrowserContext, Page } from '@playwright/test';

const scenarioPath = path.resolve(__dirname, './playwright_credential_roles.yaml');
const seededPassword = 'changeme123456';

test.describe('credential-based account flows - provisioned roles @pr', () => {
  test.describe.configure({ timeout: 120_000 });

  test('system admin author credential lifecycle', async ({
    context,
    page,
    request,
    seedScenario,
  }, testInfo) => {
    const suffix = `${Date.now()}-${testInfo.parallelIndex}-admin`;
    await seedScenario(scenarioPath, { RUN_ID: `-${suffix}` });

    await exerciseProvisionedRoleLifecycle({
      type: 'author',
      email: `admin-${suffix}@example.test`,
      destination: '/workspaces/course_author',
      accountLabel: 'Admin',
      context,
      page,
      request,
    });
  });

  test('instructor user credential lifecycle', async ({
    context,
    page,
    request,
    seedScenario,
  }, testInfo) => {
    const suffix = `${Date.now()}-${testInfo.parallelIndex}-instructor`;
    await seedScenario(scenarioPath, { RUN_ID: `-${suffix}` });

    await exerciseProvisionedRoleLifecycle({
      type: 'user',
      email: `instructor-${suffix}@example.test`,
      destination: '/workspaces/instructor',
      accountLabel: 'Instructor',
      // A plain /users/log_in submission always lands on /workspaces/student,
      // regardless of can_create_sections: the redirect target is computed
      // before current_user is assigned onto the conn. Only /instructors/log_in
      // carries an explicit request_path=/workspaces/instructor in its form
      // action, so it must be used to reach the instructor destination.
      loginPath: '/instructors/log_in',
      context,
      page,
      request,
    });
  });
});

async function exerciseProvisionedRoleLifecycle({
  type,
  email,
  destination,
  accountLabel,
  loginPath,
  context,
  page,
  request,
}: {
  type: CredentialAccountType;
  email: string;
  destination: string;
  accountLabel: string;
  loginPath?: string;
  context: BrowserContext;
  page: Page;
  request: APIRequestContext;
}) {
  const newPassword = `Reset-${Date.now()}-${type}-password`;
  const account = new CredentialAccountPO(page, type);

  await account.login(email, seededPassword, loginPath);
  await account.expectLoginSuccess(destination);
  await account.expectAccountLabel(accountLabel);

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

  await account.login(email, seededPassword, loginPath);
  await account.expectLoginFailure();

  await account.login(email, newPassword, loginPath);
  await account.expectLoginSuccess(destination);
  await account.expectAccountLabel(accountLabel);
}
