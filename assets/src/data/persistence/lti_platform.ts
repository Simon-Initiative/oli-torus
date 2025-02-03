import { Ok, ServerError, makeRequest } from './common';

export type GenerateLaunchParamsResult = Ok<LaunchParams> | ServerError;

export type LaunchParams = {
  iss: string;
  login_hint: string;
  client_id: string;
  target_link_uri: string;
  login_url: string;
};

export function generateLTILaunchParams(clientId: string): Promise<GenerateLaunchParamsResult> {
  const params = {
    url: `/lti/platforms/generate_launch_params/${clientId}`,
    method: 'POST',
  };

  return makeRequest<Ok<LaunchParams>>(params);
}
