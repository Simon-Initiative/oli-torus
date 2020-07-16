import * as Persistence from 'data/persistence/activity';
import { PartResponse, ActivityModelSchema } from 'components/activities/types';
import { RequestHintResponse } from 'components/activities/DeliveryElement';
import { valueOr } from 'utils/common';

type Continuation = (success: any, error: any) => void;

export const defaultState = (model: ActivityModelSchema) => {
  const parts = model.authoring.parts.map((p: any) =>
    ({
      attemptNumber: 1,
      attemptGuid: p.id,
      dateEvaluated: null,
      score: null,
      outOf: null,
      response: null,
      feedback: null,
      hints: [],
      hasMoreHints: p.hints.length > 0,
      hasMoreAttempts: true,
      partId: p.id,
    }));

  return {
    attemptNumber: 1,
    attemptGuid: 'testmode',
    dateEvaluated: null,
    score: null,
    outOf: null,
    hasMoreAttempts: true,
    parts,
  };
};

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

  const div = document.getElementById(elementId) as any;

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

export const initPreviewActivityBridge = (elementId: string) => {
  // map to keep track the number of hints requested for each part
  const hintRequestCounts: {[key: string]: number} = {};

  const div = document.getElementById(elementId) as any;

  function getPart(model: any, id: string) : any {
    return model.authoring.parts.find((p: any) => p.id === id);
  }

  function submit (e: CustomEvent) {
    const props = e.detail.props;
    const continuation: Continuation = e.detail.continuation;
    const partInputs: PartResponse[] = e.detail.payload;

    Persistence.evaluate(props.model, partInputs)
    .then((result: Persistence.Evaluated) => {

      const evaluations = result.evaluations
        .map((evaluation : any) => {
          // handle any errors
          if (evaluation.error) {
            console.error('Evaluation error: ' + evaluation.error)
            return;
          }

          return {
            type: 'EvaluatedPart',
            error: evaluation.error,
            attempt_guid: evaluation.part_id,
            out_of: evaluation.result.out_of,
            score: evaluation.result.score,
            feedback: evaluation.feedback,
          };
        });

      continuation({ type: 'success', evaluations }, undefined);
    });
  }

  // IMPLEMENT THESE HANDLERS LATER IF NEEDED IN THE FUTURE
  // div.addEventListener('saveActivity', (e: any) => {}, false);
  // div.addEventListener('savePart', (e: any) => {}, false);
  // div.addEventListener('resetPart', (e: any) => {}, false);

  div.addEventListener('submitActivity', (e: any) => {
    e.preventDefault();
    e.stopPropagation();

    submit(e);
  }, false);

  div.addEventListener('resetActivity', (e: any) => {
    e.preventDefault();
    e.stopPropagation();

    const props = e.detail.props;
    const continuation: Continuation = e.detail.continuation;
    const partId = e.detail.partAttemptGuid;

    Persistence.transform(props.model)
    .then((result: Persistence.Transformed) => {
      const model = result.transformed === null ? props.model : result.transformed;

      // reset the number of hints requested for this part
      hintRequestCounts[partId] = 0;

      const attemptState = defaultState(model);
      continuation({ type: 'success', model, attemptState }, undefined);
    });
  }, false);

  div.addEventListener('submitPart', (e: any) => {
    e.preventDefault();
    e.stopPropagation();

    submit(e);
  }, false);

  div.addEventListener('requestHint', (e: any) => {
    e.preventDefault();
    e.stopPropagation();

    const props = e.detail.props;
    const continuation: Continuation = e.detail.continuation;
    const partInputs: PartResponse[] = e.detail.payload;
    const partId = e.detail.partAttemptGuid;
    const model = props.model;
    const hints = getPart(model, partId).hints;

    const nextHintIndex =  valueOr(hintRequestCounts[partId], 0);
    const hasMoreHints = hints.length > nextHintIndex + 1;
    const hint = hints[nextHintIndex];
    const response : RequestHintResponse = {
      type: 'success',
      hint,
      hasMoreHints,
    };

    // keep track the number of hints requested for this part
    hintRequestCounts[partId] = valueOr(hintRequestCounts[partId], 0) + 1;

    continuation(response, undefined);
  }, false);

};
