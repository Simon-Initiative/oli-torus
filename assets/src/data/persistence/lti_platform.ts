import { Ok, ServerError, makeRequest } from './common';

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

export function getLtiExternalToolDetails(
  projectOrCourse: 'projects' | 'sections',
  slug: string,
  activityId: string,
): Promise<LTIExternalToolDetails> {
  return fetch(`/api/v1/lti/${projectOrCourse}/${slug}/launch_details/${activityId}`, {
    method: 'GET',
  }).then((response) => {
    if (!response.ok) return Promise.reject(new Error('Failed to fetch external tool details'));

    return response.json();
  });
}

export type PlatformInstance = {
  id: string;
  client_id: string;
  custom_params: any;
  description: string;
  keyset_url: string;
  login_url: string;
  name: string;
  redirect_uris: string;
  target_link_uri: string;
};

export type AvailableExternalTools = {
  data: PlatformInstance[];
};

export function listAvailableExternalTools(): Promise<AvailableExternalTools> {
  return fetch('/api/v1/lti/platforms').then((response) => {
    if (!response.ok) return Promise.reject(new Error('Failed to fetch external tools'));

    return response.json();
  });
}
