/**
 * Runtime parameter contracts and stable expectations for the live Google OAuth login tests.
 */

export const OAUTH_ACCOUNT_CLASSES = ['learner', 'author'] as const;

type OAuthAccountClass = (typeof OAUTH_ACCOUNT_CLASSES)[number];

type OAuthAccountRuntimeParameters = {
  email: string;
  password: string;
  account_label?: string;
};

type OAuthAccountExpectations = {
  login_path: string;
  authorization_path: string;
  callback_path: string;
  landing_path: string;
  workspace_heading: string;
  account_settings_link_name: string;
  account_settings_path: string;
  logout_path: string;
};

export type OAuthAccountParameters = OAuthAccountRuntimeParameters & OAuthAccountExpectations;

export type OAuthLoginParameters = {
  accounts: Record<OAuthAccountClass, OAuthAccountRuntimeParameters>;
  timeout_ms: number;
};

export type OAuthProviderParameters = {
  name: string;
  authorization_hostname: string;
  selectors: {
    email_input: string;
    email_submit: string;
    password_input: string;
    password_submit: string;
    two_factor_challenge: string;
    consent_submit?: string;
    error_message?: string;
  };
};

export const OAUTH_PROVIDER_PARAMETERS: OAuthProviderParameters = {
  name: 'Google',
  authorization_hostname: 'accounts.google.com',
  selectors: {
    email_input: 'input[name="identifier"], input#identifierId, input[aria-label="Email or phone"]',
    email_submit: '#identifierNext',
    password_input: 'input[type="password"]:not([aria-hidden="true"]):not([name="hiddenPassword"])',
    password_submit: '#passwordNext',
    two_factor_challenge: 'text=/verify it.s you/i',
    consent_submit: 'button:has-text("Continue")',
    error_message:
      'text=/couldn.t find this account|wrong password|browser or app may not be secure|couldn.t sign you in/i',
  },
};

const OAUTH_ACCOUNT_EXPECTATIONS: Record<OAuthAccountClass, OAuthAccountExpectations> = {
  learner: {
    login_path: '/users/log_in',
    authorization_path: '/users/auth/google/new',
    callback_path: '/users/auth/google/callback',
    landing_path: '/workspaces/student',
    workspace_heading: 'Courses available',
    account_settings_link_name: 'Account Settings',
    account_settings_path: '/users/settings',
    logout_path: '/',
  },
  author: {
    login_path: '/authors/log_in',
    authorization_path: '/authors/auth/google/new',
    callback_path: '/authors/auth/google/callback',
    landing_path: '/workspaces/course_author',
    workspace_heading: 'Course Author',
    account_settings_link_name: 'Edit Account',
    account_settings_path: '/authors/settings',
    logout_path: '/authors/log_in',
  },
};

const CONFIG_PATH = 'tests.oauth_logins';

/**
 * Validates required OAuth parameters and rejects placeholder runtime values.
 */
export function validateOAuthLoginParameters(
  parameters: OAuthLoginParameters,
): OAuthLoginParameters {
  requirePositiveInteger(parameters?.timeout_ms, 'timeout_ms');

  OAUTH_ACCOUNT_CLASSES.forEach((accountClass) => {
    const account = parameters?.accounts?.[accountClass];
    const path = `accounts.${accountClass}`;

    requireRuntimeValue(account?.email, `${path}.email`);
    requireRuntimeValue(account?.password, `${path}.password`);
    optionalString(account?.account_label, `${path}.account_label`);
  });

  return parameters;
}

/**
 * Combines environment-specific credentials with the stable expectations for an account class.
 */
export function oauthAccountParameters(
  parameters: OAuthLoginParameters,
  accountClass: OAuthAccountClass,
): OAuthAccountParameters {
  return {
    ...OAUTH_ACCOUNT_EXPECTATIONS[accountClass],
    ...parameters.accounts[accountClass],
  };
}

function requireString(value: unknown, path: string) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${CONFIG_PATH}.${path} must be a non-empty string`);
  }
}

function optionalString(value: unknown, path: string) {
  if (value !== undefined) {
    requireString(value, path);
  }
}

function requireRuntimeValue(value: unknown, path: string) {
  requireString(value, path);

  if (typeof value === 'string' && value.startsWith('REPLACE_WITH_')) {
    throw new Error(`${CONFIG_PATH}.${path} still contains a placeholder value`);
  }
}

function requirePositiveInteger(value: unknown, path: string) {
  if (!Number.isInteger(value) || (value as number) <= 0) {
    throw new Error(`${CONFIG_PATH}.${path} must be a positive integer`);
  }
}
