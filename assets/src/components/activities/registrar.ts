import { makeRequest } from 'data/persistence/common';

export interface RegistrationResult {
  result: 'success';
}
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
