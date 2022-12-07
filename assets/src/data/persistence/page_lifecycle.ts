import { SectionSlug } from 'data/types';
import { makeRequest, ServerError } from './common';

export type ActionSuccess = {
  result: 'success';
  commandResult: 'success';
  redirectTo: string;
};

export type ActionFailure = {
  result: 'success';
  commandResult: 'failure';
  reason: string;
  redirectTo: string;
};

export type ActionResult = ActionSuccess | ActionFailure;

export function finalizePageAttempt(
  sectionSlug: SectionSlug,
  revisionSlug: string,
  attemptGuid: string,
): Promise<ActionResult | ServerError> {
  const body = {
    action: 'finalize',
    section_slug: sectionSlug,
    revision_slug: revisionSlug,
    attempt_guid: attemptGuid,
  };
  const params = {
    method: 'POST',
    body: JSON.stringify(body),
    url: `/page_lifecycle`,
  };

  return makeRequest<ActionResult>(params);
}
