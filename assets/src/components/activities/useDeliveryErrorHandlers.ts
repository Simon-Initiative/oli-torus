import { useCallback, useState } from 'react';
import { PartResponse, StudentResponse, Success } from './types';

interface UseDeliveryErrorHandlersParams {
  onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>;
  onSavePart: (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => Promise<Success>;
}

export const useDeliveryErrorHandlers = (params: UseDeliveryErrorHandlersParams) => {
  const [error, setError] = useState<string | null>(null);

  const onSaveActivity = useCallback(
    async (attemptGuid: string, partResponses: PartResponse[]): Promise<Success> => {
      try {
        const result = await params.onSaveActivity(attemptGuid, partResponses);
        setError(null);
        return result;
      } catch (e) {
        setError(`Could not save activity (${e.message})`);
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
  };
};
