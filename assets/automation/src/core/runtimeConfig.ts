import { TYPE_USER, TypeUser } from '@pom/types/type-user';

type LoginRecord = {
  type: (typeof TYPE_USER)[keyof typeof TYPE_USER];
  pageTitle: string;
  role: string;
  welcomeText: string;
  welcomeTitle: string;
  email: string;
  pass: string;
  header?: string;
  name?: string;
  last_name?: string;
};

type RuntimeConfig = {
  baseUrl?: string;
  scenarioToken?: string;
  autoCloseBrowser?: boolean;
  loginData?: Record<TypeUser, LoginRecord>;
};

let runtimeConfig: RuntimeConfig = {};

export function setRuntimeConfig(update: RuntimeConfig) {
  runtimeConfig = { ...runtimeConfig, ...update };
}

export function getRuntimeConfig(): RuntimeConfig {
  return runtimeConfig;
}

export function getLoginData(role: TypeUser): LoginRecord {
  const data = runtimeConfig.loginData?.[role];
  if (!data) {
    throw new Error(`Runtime login data for role '${role}' is not configured`);
  }
  return data;
}

export function getBaseUrl(): string {
  return runtimeConfig.baseUrl || 'http://localhost';
}

export function getScenarioToken(): string {
  return runtimeConfig.scenarioToken || 'my-token';
}

export function shouldAutoCloseBrowser(): boolean {
  return runtimeConfig.autoCloseBrowser === true;
}
