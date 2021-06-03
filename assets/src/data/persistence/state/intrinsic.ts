import { makeRequest } from '../common';

export type BulkAttemptRetrieved = {
  result: 'success';
  activityAttempts: any[];
};

export const getBulkAttemptState = async (sectionSlug: string, attemptGuids: string[]) => {
  const params = {
    method: 'POST',
    url: `/state/course/${sectionSlug}/activity_attempt`,
    body: JSON.stringify({ attemptGuids }),
  };

  const response = await makeRequest<BulkAttemptRetrieved>(params);
  if (response.result !== 'success') {
    throw new Error(`Server ${response.status} error: ${response.message}`);
  }

  return response.activityAttempts;
};

export const getPageAttemptState = async (sectionSlug: string, resourceAttemptGuid: string) => {
  const url = `/state/course/${sectionSlug}/resource_attempt/${resourceAttemptGuid}`;
  const result = await makeRequest({
    url,
    method: 'GET',
  });
  return { result };
};

export const writePageAttemptState = async (
  sectionSlug: string,
  resourceAttemptGuid: string,
  state: any,
) => {
  const method = 'PUT';
  const url = `/state/course/${sectionSlug}/resource_attempt/${resourceAttemptGuid}`;
  const result = await makeRequest({
    url,
    method,
    body: JSON.stringify(state),
  });
  return { result };
};

export const writeActivityAttemptState = async (
  sectionSlug: string,
  attemptGuid: string,
  partResponses: any,
  finalize = false,
) => {
  const method = finalize ? 'PUT' : 'PATCH';
  const url = `/state/course/${sectionSlug}/activity_attempt/${attemptGuid}`;
  const result = await makeRequest({
    url,
    method,
    body: JSON.stringify({ partInputs: partResponses }),
  });
  return { result };
};

export const writePartAttemptState = async (
  sectionSlug: string,
  attemptGuid: string,
  partAttemptGuid: string,
  input: any,
  finalize = false,
) => {
  const method = finalize ? 'PUT' : 'PATCH';
  const url = `/state/course/${sectionSlug}/activity_attempt/${attemptGuid}/part_attempt/${partAttemptGuid}`;
  const result = await makeRequest({
    url,
    method,
    body: JSON.stringify({ response: input }),
  });
  return { result };
};
