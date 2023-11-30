import { useCallback, useState } from 'react';
import { EvaluationResponse, ResetActivityResponse } from './DeliveryElement';
import { PartResponse, StudentResponse, Success } from './types';

type SaveActivityCallback = (
  attemptGuid: string,
  partResponses: PartResponse[],
) => Promise<Success>;

interface UseDeliveryErrorHandlersParams {
  onSaveActivity: SaveActivityCallback;
  onSavePart: (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => Promise<Success>;
  onSubmitActivity: (
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => Promise<EvaluationResponse>;
  onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>;
  onSubmitPart: (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => Promise<EvaluationResponse>;
}

export const useDeliveryErrorHandlers = (params: UseDeliveryErrorHandlersParams) => {
  const [error, setError] = useState<string | null>(null);

  const onSubmitPart = useCallback(
    async (
      attemptGuid: string,
      partAttemptGuid: string,
      response: StudentResponse,
    ): Promise<EvaluationResponse> => {
      try {
        return await params.onSubmitPart(attemptGuid, partAttemptGuid, response);
      } catch (e) {
        setError(`Could not submit part (${e.message})`);
        throw e;
      }
    },
    [params.onSubmitPart],
  );

  const onResetActivity = useCallback(
    async (attemptGuid: string): Promise<ResetActivityResponse> => {
      try {
        const result = await params.onResetActivity(attemptGuid);
        setError(null);
        return result;
      } catch (e) {
        setError(`Could not reset activity (${e.message})`);
        throw e;
      }
    },
    [params.onResetActivity],
  );

  const onSubmitActivity = useCallback(
    async (attemptGuid: string, partResponses: PartResponse[]): Promise<EvaluationResponse> => {
      try {
        const result = await params.onSubmitActivity(attemptGuid, partResponses);
        setError(null);
        return result;
      } catch (e) {
        setError(`Could not submit activity (${e.message})`);
        throw e;
      }
    },
    [params.onSubmitActivity],
  );

  const onSaveActivity = useCallback(
    async (attemptGuid: string, partResponses: PartResponse[]): Promise<Success> => {
      const _saveActivity = () =>
        params
          .onSaveActivity(attemptGuid, partResponses)
          .then((result) => {
            removeActivitySaveRetry(attemptGuid); // Whenever we successfully save, remove any pending retries
            return result;
          })
          .catch((e) => {
            throw e;
          });

      try {
        const result = await _saveActivity();
        setError(null);
        return result;
      } catch (e) {
        setError(`Could not save activity (${e.message})`);
        queueActivitySaveRetry(partResponses, attemptGuid, params.onSaveActivity);
        throw e;
      }
    },
    [params.onSaveActivity],
  );

  const onSavePart = useCallback(
    async (
      attemptGuid: string,
      partAttemptGuid: string,
      response: StudentResponse,
    ): Promise<Success> => {
      try {
        return await params.onSavePart(attemptGuid, partAttemptGuid, response);
      } catch (e) {
        setError(`Could not save part (${e.message})`);
        throw e;
      }
    },
    [params.onSavePart],
  );

  return {
    error,
    onSaveActivity,
    onSavePart,
    onSubmitActivity,
    onSubmitPart,
    onResetActivity,
  };
};

interface RequestRetry {
  id: string;
  responses: PartResponse[];
  fn: () => Promise<Success>;
}

export function getActivitySaveRetry(id: string) {
  if (!window.retryQueue) return null;
  return window.retryQueue.find((r) => r.id === id);
}

export function removeActivitySaveRetry(id: string) {
  if (!window.retryQueue) return;
  const index = window.retryQueue.findIndex((r) => r.id === id);
  if (index !== -1) {
    window.retryQueue.splice(index, 1);
  }
}

/**
 * If you have a failed activity save, you can queue it for retry right before the finalization.
 */
export function queueActivitySaveRetry(
  responses: PartResponse[],
  id: string,
  onSaveActivity: SaveActivityCallback,
) {
  const existingEntry = getActivitySaveRetry(id);

  if (existingEntry) {
    mergeResponses(existingEntry.responses, responses);
    existingEntry.fn = () => onSaveActivity(id, existingEntry.responses);
  } else {
    // Add it to the queue
    window.retryQueue = window.retryQueue || [];
    window.retryQueue.push({
      id,
      responses,
      fn: () => onSaveActivity(id, responses),
    });
  }
}

function mergeResponses(existingResponses: PartResponse[], newResponses: PartResponse[]) {
  newResponses.forEach((newResponse) => {
    const existingResponse = existingResponses.find(
      (r) => r.attemptGuid === newResponse.attemptGuid,
    );
    if (existingResponse) {
      existingResponse.response = newResponse.response;
    } else {
      existingResponses.push(newResponse);
    }
  });
}

declare global {
  interface Window {
    retryQueue?: RequestRetry[];
  }
}
