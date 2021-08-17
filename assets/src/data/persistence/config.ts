// Base URL to use when contacting server via JSON API
export function getBaseURL(): string {
  return window.location.protocol + '//' + window.location.host + '/api/v1';
}
