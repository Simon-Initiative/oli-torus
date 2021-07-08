import * as Persistence from 'data/persistence/activity';
import { PartResponse, ActivityModelSchema, FeedbackAction } from 'components/activities/types';
import { RequestHintResponse } from 'components/activities/DeliveryElement';
import { valueOr, removeEmpty } from 'utils/common';
import guid from 'utils/guid';

type Continuation = (success: any, error: any) => void;

export const defaultState = (model: ActivityModelSchema) => {
  const parts = model.authoring.parts.map((p: any) => ({
    attemptNumber: 1,
    attemptGuid: p.id,
    dateEvaluated: null,
    score: null,
    outOf: null,
    response: null,
    feedback: null,
    hints: [],
    hasMoreHints: removeEmpty(p.hints).length > 0,
    hasMoreAttempts: true,
    partId: p.id,
  }));

  return {
    attemptNumber: 1,
    attemptGuid: guid(),
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
  window
    .fetch(url, params)
    .then((response) => response.json())
    .then((result) => continuation(result))
    .catch((error) => continuation(undefined, error));
}

export const initActivityBridge = (elementId: string) => {
  const div = document.getElementById(elementId) as any;

  div.addEventListener(
    'saveActivity',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}`,
        'PATCH',
        { partInputs: e.detail.payload },
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'submitActivity',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}`,
        'PUT',
        { partInputs: e.detail.payload },
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'resetActivity',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}`,
        'POST',
        {},
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'savePart',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}/part_attempt/${e.detail.partAttemptGuid}`,
        'PATCH',
        { response: e.detail.payload },
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'submitPart',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}/part_attempt/${e.detail.partAttemptGuid}`,
        'PUT',
        { response: e.detail.payload },
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'resetPart',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}/part_attempt/${e.detail.partAttemptGuid}`,
        'POST',
        {},
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'requestHint',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}/part_attempt/${e.detail.partAttemptGuid}/hint`,
        'GET',
        undefined,
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'submitEvaluations',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}/evaluations`,
        'PUT',
        { evaluations: e.detail.payload },
        e.detail.continuation,
      );
    },
    false,
  );
};

const key = (activityAttemptGuid: string, partAttemptGuid: string) =>
  activityAttemptGuid + '|' + partAttemptGuid;

export const initPreviewActivityBridge = (elementId: string) => {
  // map to keep track the number of hints requested for each part
  const hintRequestCounts: { [key: string]: number } = {};

  const div = document.getElementById(elementId) as any;

  function getPart(model: any, id: string): any {
    return model.authoring.parts.find((p: any) => p.id === id);
  }

  function submit(e: CustomEvent) {
    const props = e.detail.props;
    const continuation: Continuation = e.detail.continuation;
    const partInputs: PartResponse[] = e.detail.payload;

    Persistence.evaluate(props.model, partInputs).then((result: Persistence.Evaluated) => {
      const actions: (FeedbackAction | { part_id: string; error: string })[] =
        result.evaluations.map((e) => {
          if ('error' in e) {
            return {
              part_id: e.part_id,
              error: e.error,
            };
          }
          return {
            type: 'FeedbackAction',
            attempt_guid: e.part_id,
            out_of: e.result.out_of,
            score: e.result.score,
            feedback: e.feedback,
          };
        });

      continuation({ type: 'success', actions }, undefined);
    });
  }

  // IMPLEMENT THESE HANDLERS LATER IF NEEDED IN THE FUTURE
  // div.addEventListener('saveActivity', (e: any) => {}, false);
  // div.addEventListener('savePart', (e: any) => {}, false);
  // div.addEventListener('resetPart', (e: any) => {}, false);

  div.addEventListener(
    'submitActivity',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();

      submit(e);
    },
    false,
  );

  div.addEventListener(
    'resetActivity',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();

      const props = e.detail.props;
      const continuation: Continuation = e.detail.continuation;
      const partId = e.detail.partAttemptGuid;

      Persistence.transform(props.model).then((result: Persistence.Transformed) => {
        const model = result.transformed === null ? props.model : result.transformed;

        // reset the number of hints requested for this part
        hintRequestCounts[key(e.detail.attemptGuid, e.detail.partAttemptGuid)] = 0;

        const attemptState = defaultState(model);
        continuation({ type: 'success', model, attemptState }, undefined);
      });
    },
    false,
  );

  div.addEventListener(
    'submitPart',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();

      submit(e);
    },
    false,
  );

  div.addEventListener(
    'requestHint',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();

      const hintKey = key(e.detail.attemptGuid, e.detail.partAttemptGuid);

      const props = e.detail.props;
      const continuation: Continuation = e.detail.continuation;
      const partInputs: PartResponse[] = e.detail.payload;
      const partId = e.detail.partAttemptGuid;
      const model = props.model;
      const hints = removeEmpty(getPart(model, partId).hints);

      const nextHintIndex = valueOr(hintRequestCounts[hintKey], 0);
      const hasMoreHints = hints.length > nextHintIndex + 1;
      const hint = hints[nextHintIndex];
      const response: RequestHintResponse = {
        type: 'success',
        hint,
        hasMoreHints,
      };

      // keep track the number of hints requested for this part
      hintRequestCounts[hintKey] = valueOr(hintRequestCounts[hintKey], 0) + 1;

      continuation(response, undefined);
    },
    false,
  );
};
