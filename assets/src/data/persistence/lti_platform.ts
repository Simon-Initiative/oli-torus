import { Ok, ServerError, makeRequest } from './common';

export type LTIExternalToolDetailsResult = Ok<LTIExternalToolDetails> | ServerError;

export type LTIExternalToolDetails = {
  name: string;
  launch_params: {
    iss: string;
    login_hint: string;
    client_id: string;
    target_link_uri: string;
    login_url: string;
  };
};

export function getLtiExternalToolDetails(clientId: string): Promise<LTIExternalToolDetailsResult> {
  const params = {
    url: `/lti/platforms/details/${clientId}`,
    method: 'POST',
  };

  return makeRequest<Ok<LTIExternalToolDetails>>(params);
}
