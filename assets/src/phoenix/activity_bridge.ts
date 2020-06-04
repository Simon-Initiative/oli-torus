

function makeRequest(url: string, method: string, body: any, continuation: any) {
  const params = {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  };
  window.fetch(url, params)
    .then(response => response.json())
    .then(result => continuation(result))
    .catch(error => continuation(undefined, error));
}

export const initActivityBridge = (elementId: string) => {

  const div = document.getElementById('eventIntercept') as any;

  div.addEventListener('saveActivity', (e: any) => {
    e.preventDefault();
    e.stopPropagation();
    makeRequest('/api/v1/attempt/activity/' + e.detail.attemptGuid,
      'PATCH', { partInputs: e.detail.payload }, e.detail.continuation);
  }, false);

  div.addEventListener('submitActivity', (e: any) => {
    e.preventDefault();
    e.stopPropagation();
    makeRequest('/api/v1/attempt/activity/' + e.detail.attemptGuid,
      'PUT', { partInputs: e.detail.payload }, e.detail.continuation);
  }, false);

  div.addEventListener('resetActivity', (e: any) => {
    e.preventDefault();
    e.stopPropagation();
    makeRequest('/api/v1/attempt/activity/' + e.detail.attemptGuid,
      'POST', {}, e.detail.continuation);
  }, false);

  div.addEventListener('savePart', (e: any) => {
    e.preventDefault();
    e.stopPropagation();
    makeRequest(
      '/api/v1/attempt/activity/' + e.detail.attemptGuid + '/part/' + e.detail.partAttemptGuid,
      'PATCH', { input: e.detail.payload }, e.detail.continuation);
  }, false);

  div.addEventListener('submitPart', (e: any) => {
    e.preventDefault();
    e.stopPropagation();
    makeRequest(
      '/api/v1/attempt/activity/' + e.detail.attemptGuid + '/part/' + e.detail.partAttemptGuid,
      'PUT', { input: e.detail.payload }, e.detail.continuation);
  }, false);

  div.addEventListener('resetPart', (e: any) => {
    e.preventDefault();
    e.stopPropagation();
    makeRequest(
      '/api/v1/attempt/activity/' + e.detail.attemptGuid + '/part/' + e.detail.partAttemptGuid, 'POST', {}, e.detail.continuation);
  }, false);

  div.addEventListener('requestHint', (e: any) => {
    e.preventDefault();
    e.stopPropagation();
    makeRequest(
      '/api/v1/attempt/activity/' + e.detail.attemptGuid + '/part/' + e.detail.partAttemptGuid + '/hint',
      'GET', undefined, e.detail.continuation);
  }, false);
};
