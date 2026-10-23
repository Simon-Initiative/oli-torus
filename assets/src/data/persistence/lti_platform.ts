import { ActivityModelSchema } from 'components/activities/types';

export type LTIExternalToolDetails = {
  request_id?: string;
  request_token?: string;
  name: string;
  launch_params: {
    iss: string;
    login_hint: string;
    client_id: string;
    target_link_uri: string;
    login_url: string;
    lti_deployment_id?: string;
    lti_message_hint?: string;
    lti_message_type?: string;
  };
  status: string;
  deep_linking_enabled: boolean;
  deep_link?: {
    type: string;
    url?: string | null;
    title: string;
    text: string;
  };
  can_configure_tool: boolean;
};

export function getLtiExternalToolDetails(
  projectsOrSections: 'projects' | 'sections',
  slug: string,
  activityId: string,
  options?: { role: 'developer' | 'instructor'; launch_type: 'regular' | 'deep_link' },
): Promise<LTIExternalToolDetails> {
  const query = options ? '?' + new URLSearchParams(options).toString() : '';
  return fetch(`/api/v1/lti/${projectsOrSections}/${slug}/launch_details/${activityId}${query}`, {
    method: 'GET',
  }).then((response) => {
    if (!response.ok) return Promise.reject(new Error('Failed to fetch external tool details'));

    return response.json();
  });
}

export function getLtiExternalToolDeepLinkingDetails(
  slug: string,
  activityId: string,
): Promise<LTIExternalToolDetails> {
  return fetch(`/api/v1/lti/sections/${slug}/deep_linking_launch_details/${activityId}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }).then((response) => {
    if (!response.ok)
      return Promise.reject(new Error('Failed to fetch external tool deep linking details'));

    return response.json();
  });
}

/** Cancel a configuration request; completion means its selection was already committed. */
export async function cancelLtiExternalToolDeepLinking(
  slug: string,
  activityId: string,
  requestToken: string,
): Promise<'cancelled' | 'completed'> {
  const response = await fetch(`/api/v1/lti/sections/${slug}/cancel_deep_linking/${activityId}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ request_token: requestToken }),
  });
  if (!response.ok) throw new Error('Could not close configuration. Please try Close again.');
  const result = await response.json();
  if (result.status !== 'cancelled' && result.status !== 'completed')
    throw new Error('Could not close configuration. Please try Close again.');
  return result.status;
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

/** Start configuration only after the host has persisted its pending edits. */
export async function startAuthoringDeepLink(
  project: string,
  activity: string,
  lockId: number,
  role: 'developer' | 'instructor',
): Promise<LTIExternalToolDetails> {
  const response = await fetch(
    `/api/v1/lti/projects/${project}/deep_linking_launch_details/${activity}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ lock_id: lockId, role }),
    },
  );
  if (!response.ok)
    throw new Error('Configuration requires an active editing lock. Reload and try again.');
  return response.json();
}

export type AuthoringSelectionSaved = {
  model: ActivityModelSchema;
  title: string;
  objectives: Record<string, number[]>;
  tags: number[];
};

/** Submit the trusted result token; the server derives the selection and checks freshness. */
export async function saveAuthoringDeepLink(
  project: string,
  activity: string,
  token: string,
): Promise<AuthoringSelectionSaved> {
  const response = await fetch(`/api/v1/lti/projects/${project}/deep_link_save/${activity}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token }),
  });
  if (!response.ok)
    throw new Error('Could not confirm the selection save. Reload the page before trying again.');
  return response.json();
}
