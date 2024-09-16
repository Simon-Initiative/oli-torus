import { RequestHintResponse } from 'components/activities/DeliveryElement';
import { ClientEvaluation, PartResponse } from 'components/activities/types';
import { defaultActivityState } from 'data/activities/utils';
import * as Persistence from 'data/persistence/activity';
import { removeEmpty, valueOr } from 'utils/common';

type Continuation = (success: any, error: any) => void;

function makeRequest(
  url: string,
  method: string,
  body: any,
  continuation: any,
  transform = nothingTransform,
) {
  const params = {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  };
  window
    .fetch(url, params)
    .then((response) => response.json())
    .then((result) => transform(result))
    .then((result) => continuation(result))
    .catch((error) => continuation(undefined, error));
}
const nothingTransform = (result: any) => Promise.resolve(result);
const submissionTransform = (key: string, result: any) => {
  return Promise.resolve({ actions: result[key] });
};

export const initActivityBridge = (elementId: string) => {
  const div = document.getElementById(elementId) as any;

  div.addEventListener(
    'saveActivity',
    (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      console.info('SAVE ACTIVITY');

      const originalContinuation = e.detail.continuation;

      const newContinuation = (result: any, error: any) => {
        if (!error && window.ReactToLiveView) {
          window.ReactToLiveView.pushEvent('activity_saved', {
            partInputs: e.detail.payload,
            activityAttemptGuid: e.detail.attemptGuid,
          });
        }

        if (originalContinuation) {
          originalContinuation(result, error);
        }
      };

      makeRequest(
        `/api/v1/state/course/${e.detail.sectionSlug}/activity_attempt/${e.detail.attemptGuid}`,
        'PATCH',
        { partInputs: e.detail.payload },
        newContinuation,
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
        submissionTransform.bind(this, 'actions'),
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
        { survey_id: e.detail.props.context.surveyId },
        e.detail.continuation,
      );
    },
    false,
  );

  div.addEventListener(
    'savePart',
    (e: any) => {
      console.info('SAVEPART');
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
      if (result.result === 'success') {
        submissionTransform('evaluations', result).then((actions) =>
          continuation({ type: 'success', actions: actions.actions }, undefined),
        );
      }
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

      Persistence.transform(props.model).then((result: Persistence.Transformed) => {
        const model = result.transformed === null ? props.model : result.transformed;

        // reset the number of hints requested for this part
        hintRequestCounts[key(e.detail.attemptGuid, e.detail.partAttemptGuid)] = 0;

        const attemptState = defaultActivityState(model);
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

      const props = e.detail.props;
      const continuation: Continuation = e.detail.continuation;
      const partInputs: PartResponse[] = [
        { response: e.detail.payload, attemptGuid: e.detail.partAttemptGuid },
      ];

      Persistence.evaluate(props.model, partInputs).then((result: Persistence.Evaluated) => {
        if (result.result === 'success') {
          submissionTransform('evaluations', result).then((actions) =>
            continuation({ type: 'success', actions: actions.actions }, undefined),
          );
        }
      });
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

  div.addEventListener('submitEvaluations', (e: any) => {
    e.preventDefault();
    e.stopPropagation();

    const continuation: Continuation = e.detail.continuation;
    const clientEvaluations: ClientEvaluation[] = e.detail.payload;
    const evaluatedParts = clientEvaluations.map((clientEval: any) => {
      return {
        type: 'EvaluatedPart',
        out_of: clientEval.out_of,
        score: clientEval.score,
        feedback: clientEval.feedback,
      };
    });

    continuation({ type: 'success', actions: evaluatedParts }, undefined);
  });
};
