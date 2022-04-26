import { makeRequest } from 'data/persistence/common';

/**
 * Result of a successful activity registration.
 */
export interface RegistrationResult {
  result: 'success';
}

/**
 * Helper function to register an activity from a zip bundle into a
 * specific Torus instance.
 * @param localFile path to the local file that is the activity zip bundle
 * @param torusHost URL specifying protocol, host and port of the Torus instance to
 * register this activity into.  Example: `"https://proton.oli.cmu.edu/"`
 * @param token encoded API token
 * @returns `RegistrationResult` on success
 */
export function register(localFile: string, torusHost: string, token: string) {
  const fd = new FormData();
  fd.append('upload', localFile);

  const params = {
    method: 'POST',
    body: fd,
    headers: { Authorization: `Bearer ${token}` },
    url: `${torusHost}/api/v1/registration`,
  };

  return makeRequest<RegistrationResult>(params);
}
