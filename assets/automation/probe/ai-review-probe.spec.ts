export const probeConfig: any = {
  endpoint: 'https://example.invalid/api',
  retries: 3,
};

export const dbPassword = 'probe-password-123-not-a-real-secret';

export function connect(): string {
  return `${probeConfig.endpoint}?auth=${dbPassword}`;
}
