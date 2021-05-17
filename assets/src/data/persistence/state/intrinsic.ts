import {
  defaultGlobalEnv,
  evalScript,
  getAssignScript,
  getEnvState,
} from '../../../adaptivity/scripting';
import { makeRequest } from '../common';

export type BulkAttemptRetrieved = {
  result: 'success';
  activityAttempts: any[];
};

export const getBulkAttemptState = async (
  sectionSlug: string,
  attemptGuids: string[],
  previewMode = false,
) =>
  previewMode
    ? getBulkAttemptStateClient(sectionSlug, attemptGuids)
    : getBulkAttemptStateServer(sectionSlug, attemptGuids);

const getBulkAttemptStateServer = async (sectionSlug: string, attemptGuids: string[]) => {
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

const getBulkAttemptStateClient = async (sectionSlug: string, attemptGuids: string[]) => {
  return [];
};

export const getPageAttemptState = async (
  sectionSlug: string,
  resourceAttemptGuid: string,
  previewMode = false,
): Promise<any> =>
  previewMode
    ? getPageAttemptStateClient(sectionSlug, resourceAttemptGuid)
    : getPageAttemptStateServer(sectionSlug, resourceAttemptGuid);

const getPageAttemptStateClient = async (sectionSlug: string, resourceAttemptGuid: string) => {
  // on the client side, there is really only one attempt..
  // could do a map of client guid to env? revisit with history mode??
  const allState = getEnvState(defaultGlobalEnv);
  // TODO: convert to capi var? probably needs to be typed for coersion
  return Object.keys(allState).map((key) => ({ id: key, value: allState[key] }));
};

const getPageAttemptStateServer = async (sectionSlug: string, resourceAttemptGuid: string) => {
  const url = `/course/${sectionSlug}/resource_attempt/${resourceAttemptGuid}`;
  return [];
};

export const writePageAttemptState = async (
  sectionSlug: string,
  resourceAttemptGuid: string,
  state: any,
  previewMode = false,
): Promise<any> =>
  previewMode
    ? writePageAttemptStateClient(sectionSlug, resourceAttemptGuid, state)
    : writePageAttemptStateServer(sectionSlug, resourceAttemptGuid, state);

const writePageAttemptStateClient = async (
  sectionSlug: string,
  resourceAttemptGuid: string,
  state: any,
) => {
  // on the client side, there is really only one attempt..
  // could do a map of client guid to env? revisit with history mode??
  const assignScript = getAssignScript(state);
  const { result } = evalScript(assignScript, defaultGlobalEnv);
  return { result };
};

const writePageAttemptStateServer = async (
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
  previewMode = false,
): Promise<any> =>
  previewMode
    ? writeActivityAttemptStateClient(sectionSlug, attemptGuid, partResponses, finalize)
    : writeActivityAttemptStateServer(sectionSlug, attemptGuid, partResponses, finalize);

const writeActivityAttemptStateClient = async (
  sectionSlug: string,
  attemptGuid: string,
  partResponses: any,
  finalize = false,
) => {
  // on the client side, there is really only one attempt..
  // could do a map of client guid to env? revisit with history mode??
  const assignScript = getAssignScript(partResponses);
  const { result } = evalScript(assignScript, defaultGlobalEnv);
  return { result };
};

const writeActivityAttemptStateServer = async (
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
  previewMode = false,
): Promise<any> =>
  previewMode
    ? writePartAttemptStateClient(sectionSlug, attemptGuid, partAttemptGuid, input, finalize)
    : writePartAttemptStateServer(sectionSlug, attemptGuid, partAttemptGuid, input, finalize);

const writePartAttemptStateClient = async (
  sectionSlug: string,
  attemptGuid: string,
  partAttemptGuid: string,
  input: any,
  finalize = false,
) => {
  // on the client side, there is really only one attempt..
  // could do a map of client guid to env? revisit with history mode??
  const assignScript = getAssignScript(input);
  const { result } = evalScript(assignScript, defaultGlobalEnv);
  return { result };
};

const writePartAttemptStateServer = async (
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
