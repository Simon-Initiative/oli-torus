import { SectionSlug } from '../types';
import { ServerError, makeRequest } from './common';

export type TriggerPayload = {
  trigger_type: string;
  resource_id: number;
  data: any;
  prompt: string;
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
  section_slug: SectionSlug, payload: TriggerPayload
): Promise<InvocationResult> {
  const url = `/triggers/${section_slug}`;

  const params = {
    url,
    method: 'POST',
    body: JSON.stringify(payload),
  };
  return makeRequest<InvocationResult>(params);
}

export function getInstanceId(): string | null {

  // Fetch the dom element whose id is "ai_bot" and then
  // return the value of the "data-instance-id" attribute.

  const ai_bot = document.getElementById("ai_bot");

  // If the element does not exist, return null.
  if (!ai_bot) {
    return null;
  }
  else {
    return ai_bot.getAttribute("data-instance-id");
  }
}
