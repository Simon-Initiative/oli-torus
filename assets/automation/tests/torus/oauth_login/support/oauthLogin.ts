import { Utils } from '@core/Utils';
import { expect, Page, Response } from '@playwright/test';
import { OAuthAccountParameters, OAUTH_PROVIDER_PARAMETERS } from './oauthLoginConfig';

/**
 * Provider interaction and Torus login-page helpers for the live OAuth tests.
 */

/**
 * Completes the configured provider prompts and returns the Torus callback response.
 * Throws when the provider reports an authentication or consent error.
 */
export async function completeOAuthProviderLogin(
  page: Page,
  account: OAuthAccountParameters,
  isCallbackResponse: (response: Response) => boolean,
  timeout: number,
): Promise<Response> {
  const provider = OAUTH_PROVIDER_PARAMETERS;
  const providerError = provider.selectors.error_message
    ? page.locator(provider.selectors.error_message).first()
    : undefined;
  const twoFactorChallenge = page.locator(provider.selectors.two_factor_challenge).first();
  const emailInput = page.locator(provider.selectors.email_input);

  await waitForProviderElement(
    emailInput,
    providerError,
    twoFactorChallenge,
    timeout,
    'email prompt',
  );
  await emailInput.fill(account.email);
  await page.locator(provider.selectors.email_submit).click();

  const passwordInput = page.locator(provider.selectors.password_input);

  await waitForProviderElement(
    passwordInput,
    providerError,
    twoFactorChallenge,
    timeout,
    'password prompt',
  );
  await passwordInput.fill(account.password);

  // Start observing before submit so a fast callback redirect cannot be missed.
  const callbackResponsePromise = page.waitForResponse(isCallbackResponse, { timeout });

  // Keep an interrupted provider flow from leaving a rejected waiter behind.
  void callbackResponsePromise.catch(() => undefined);

  await page.locator(provider.selectors.password_submit).click();

  const consentSelector = provider.selectors.consent_submit;

  // Providers may redirect immediately, pause for consent, or reject authentication.
  const outcome = await Promise.race([
    callbackResponsePromise.then((response) => ({ kind: 'callback' as const, response })),
    waitForProviderError(providerError, timeout),
    waitForTwoFactorChallenge(twoFactorChallenge, timeout),
    ...(consentSelector
      ? [
          page
            .locator(consentSelector)
            .first()
            .waitFor({ state: 'visible', timeout })
            .then(() => ({ kind: 'consent' as const })),
        ]
      : []),
  ]);

  if (outcome.kind === 'error') {
    return throwProviderError(providerError, 'authentication');
  }

  if (outcome.kind === 'two-factor') {
    return throwTwoFactorChallenge();
  }

  if (outcome.kind === 'consent') {
    if (!consentSelector) {
      throw new Error('OAuth provider reached consent without a configured consent selector');
    }

    const consentButton = page.locator(consentSelector).first();

    await consentButton.click();

    const postConsentOutcome = await Promise.race([
      callbackResponsePromise.then((response) => ({ kind: 'callback' as const, response })),
      waitForProviderError(providerError, timeout),
      waitForTwoFactorChallenge(twoFactorChallenge, timeout),
    ]);

    if (postConsentOutcome.kind === 'error') {
      return throwProviderError(providerError, 'consent');
    }

    if (postConsentOutcome.kind === 'two-factor') {
      return throwTwoFactorChallenge();
    }

    return postConsentOutcome.response;
  }

  return outcome.response;
}

async function waitForProviderElement(
  element: ReturnType<Page['locator']>,
  providerError: ReturnType<Page['locator']> | undefined,
  twoFactorChallenge: ReturnType<Page['locator']>,
  timeout: number,
  phase: string,
) {
  const outcome = await Promise.race([
    element.waitFor({ state: 'visible', timeout }).then(() => 'element' as const),
    waitForProviderError(providerError, timeout).then(() => 'error' as const),
    waitForTwoFactorChallenge(twoFactorChallenge, timeout).then(() => 'two-factor' as const),
  ]);

  if (outcome === 'error') {
    await throwProviderError(providerError, phase);
  }

  if (outcome === 'two-factor') {
    throwTwoFactorChallenge();
  }
}

function waitForProviderError(
  providerError: ReturnType<Page['locator']> | undefined,
  timeout: number,
) {
  if (!providerError) {
    return new Promise<{ kind: 'error' }>(() => {});
  }

  return providerError
    .waitFor({ state: 'visible', timeout })
    .then(() => ({ kind: 'error' as const }));
}

function waitForTwoFactorChallenge(
  twoFactorChallenge: ReturnType<Page['locator']>,
  timeout: number,
) {
  return twoFactorChallenge
    .waitFor({ state: 'visible', timeout })
    .then(() => ({ kind: 'two-factor' as const }));
}

function throwTwoFactorChallenge(): never {
  throw new Error(
    'Google displayed the "Verify it\'s you" page. The OAuth test account must have 2FA disabled.',
  );
}

async function throwProviderError(
  providerError: ReturnType<Page['locator']> | undefined,
  phase: string,
): Promise<never> {
  const message = await providerError?.innerText().catch(() => '');

  throw new Error(
    `OAuth provider rejected the ${phase}${message?.trim() ? `: ${message.trim()}` : ''}`,
  );
}

/**
 * Dismisses the Torus cookie consent prompt when it is visible.
 */
export async function acceptTorusCookiesIfVisible(page: Page) {
  const cookieModal = page.locator('#cookie_consent_display');
  const acceptButton = cookieModal.locator('button:has-text("Accept")').first();
  const appeared = await acceptButton
    .waitFor({ state: 'visible', timeout: 3_000 })
    .then(() => true)
    .catch(() => false);

  if (appeared) {
    // A normal click waits for the button to settle instead of racing Bootstrap's transition.
    await acceptButton.click();
    await expect(cookieModal).toBeHidden({ timeout: 5_000 });

    // Recover if the React unmount leaves Bootstrap's backdrop intercepting later clicks.
    await new Utils(page).modalDisappears();
  }
}
