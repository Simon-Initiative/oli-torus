/**
 * Runtime parameter contracts and validation for the live OAuth login tests.
 */

export const OAUTH_ACCOUNT_CLASSES = ['learner', 'author'] as const;

type OAuthAccountClass = (typeof OAUTH_ACCOUNT_CLASSES)[number];

export type OAuthAccountParameters = {
  email: string;
  password: string;
  torus_account_name: string;
  login_path: string;
  authorization_path: string;
  callback_path: string;
  landing_path: string;
  workspace_heading: string;
  account_settings_link_name: string;
  account_settings_path: string;
  account_label?: string;
  logout_path: string;
};

export type OAuthLoginParameters = {
  provider: {
    name: string;
    authorization_hostname: string;
    selectors: {
      email_input: string;
      email_submit: string;
      password_input: string;
      password_submit: string;
      consent_submit?: string;
      error_message?: string;
    };
  };
  accounts: Record<OAuthAccountClass, OAuthAccountParameters>;
  timeout_ms: number;
};

const CONFIG_PATH = 'tests.oauth_logins';

/**
 * Validates required OAuth parameters and rejects placeholder runtime values.
 */
export function validateOAuthLoginParameters(
  parameters: OAuthLoginParameters,
): OAuthLoginParameters {
  requirePositiveInteger(parameters?.timeout_ms, 'timeout_ms');
  requireString(parameters?.provider?.name, 'provider.name');
  requireHostname(parameters?.provider?.authorization_hostname, 'provider.authorization_hostname');
  requireString(parameters?.provider?.selectors?.email_input, 'provider.selectors.email_input');
  requireString(parameters?.provider?.selectors?.email_submit, 'provider.selectors.email_submit');
  requireString(
    parameters?.provider?.selectors?.password_input,
    'provider.selectors.password_input',
  );
  requireString(
    parameters?.provider?.selectors?.password_submit,
    'provider.selectors.password_submit',
  );
  optionalString(
    parameters?.provider?.selectors?.consent_submit,
    'provider.selectors.consent_submit',
  );
  optionalString(
    parameters?.provider?.selectors?.error_message,
    'provider.selectors.error_message',
  );

  OAUTH_ACCOUNT_CLASSES.forEach((accountClass) => {
    const account = parameters?.accounts?.[accountClass];
    const path = `accounts.${accountClass}`;

    requireRuntimeValue(account?.email, `${path}.email`);
    requireRuntimeValue(account?.password, `${path}.password`);
    requireRuntimeValue(account?.torus_account_name, `${path}.torus_account_name`);
    requireLocalPath(account?.login_path, `${path}.login_path`);
    requireLocalPath(account?.authorization_path, `${path}.authorization_path`);
    requireLocalPath(account?.callback_path, `${path}.callback_path`);
    requireLocalPath(account?.landing_path, `${path}.landing_path`);
    requireString(account?.workspace_heading, `${path}.workspace_heading`);
    requireString(account?.account_settings_link_name, `${path}.account_settings_link_name`);
    requireLocalPath(account?.account_settings_path, `${path}.account_settings_path`);
    optionalString(account?.account_label, `${path}.account_label`);
    requireLocalPath(account?.logout_path, `${path}.logout_path`, true);
  });

  return parameters;
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

function requireHostname(value: unknown, path: string) {
  requireString(value, path);

  try {
    const url = new URL(`https://${value}`);

    if (url.hostname !== value || url.pathname !== '/') {
      throw new Error();
    }
  } catch {
    throw new Error(`${CONFIG_PATH}.${path} must be a hostname without a scheme or path`);
  }
}

function requireLocalPath(value: unknown, path: string, allowRoot = false) {
  requireString(value, path);

  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//')) {
    throw new Error(`${CONFIG_PATH}.${path} must be a local absolute path`);
  }

  const parsed = new URL(value, 'https://torus.invalid');

  if (parsed.pathname !== value || (!allowRoot && parsed.pathname === '/')) {
    throw new Error(`${CONFIG_PATH}.${path} must be a local absolute path without a query or hash`);
  }
}
