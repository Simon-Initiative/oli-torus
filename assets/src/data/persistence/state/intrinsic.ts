import { makeRequest } from "../common";

export type BulkAttemptRetrieved = {
  result: "success";
  activityAttempts: any[];
};

export const getBulkAttemptState = async (
  sectionSlug: string,
  attemptGuids: string[]
) => {
  const params = {
    method: "POST",
    url: `/state/course/${sectionSlug}/activity_attempt`,
    body: JSON.stringify({ attemptGuids }),
  };

  const response = await makeRequest<BulkAttemptRetrieved>(params);
  if (response.result !== "success") {
    throw new Error(`Server ${response.status} error: ${response.message}`);
  }

  return response.activityAttempts;
};