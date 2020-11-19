import { makeRequest, Ok, ServerError } from './common';

export type FetchPreferencesResult = Preferences | ServerError;
export type UpdatePreferencesResult = Ok | ServerError;

export type Preferences = {
  ['theme']: string | null,
  ['live_preview_display']: string | null
};

export function fetchPreferences(): Promise<FetchPreferencesResult> {

  const params = {
    url: `/account/preferences`,
    method: 'GET',
  };
  return makeRequest<FetchPreferencesResult>(params);
}

export function updatePreferences(preferences: Partial<Preferences>): Promise<UpdatePreferencesResult> {

  const params = {
    url: `/account/preferences`,
    method: 'POST',
    body: JSON.stringify(preferences),
    hasTextResult: true,
  };
  return makeRequest<UpdatePreferencesResult>(params);
}
