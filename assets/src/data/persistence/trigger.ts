import { SectionSlug } from '../types';
import { ServerError, makeRequest } from './common';

export type TriggerPayload = {
  trigger_type: string;
  resource_id: number;
  data: any;
  prompt?: string;
};

export type InvocationResult = Submitted | Failed | ServerError;

export type Submitted = {
  type: 'submitted';
};

export type Failed = {
  type: 'failed';
  reason: string;
};

export function invoke(
  section_slug: SectionSlug,
  payload: TriggerPayload,
): Promise<InvocationResult> {
  const url = `/triggers/${section_slug}`;

  const params = {
    url,
    method: 'POST',
    body: JSON.stringify({ trigger: payload }),
  };
  return makeRequest<InvocationResult>(params);
}

export function hasDialogueWindow(): boolean {
  if (document.getElementById('ai_bot') !== null) {
    return true;
  }

  // Adaptive delivery runs inside an iframe; the DOT dialogue window
  // lives in the parent frame. Check same-origin parent when available.
  try {
    if (window.parent !== window) {
      if (window.parent.document.getElementById('ai_bot') !== null) {
        return true;
      }
    }
  } catch (_e) {
    // Cross-origin access denied — ignore.
  }

  return false;
}
