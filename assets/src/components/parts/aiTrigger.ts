import * as Trigger from 'data/persistence/trigger';
import { SectionSlug } from 'data/types';

export type AdaptiveAiTriggerType = 'adaptive_page' | 'adaptive_component' | 'trap_state';

export interface AdaptiveAiTriggerConfig {
  sectionSlug?: SectionSlug;
  resourceId?: number;
  triggerType: AdaptiveAiTriggerType;
  data?: Record<string, unknown>;
  prompt?: string;
}

export const hasAiTriggerPrompt = (prompt?: string | null): prompt is string =>
  Boolean(prompt?.trim());

export const canInvokeAiTrigger = () => Trigger.hasDialogueWindow();

export const buildAdaptiveAiTriggerPayload = ({
  resourceId,
  triggerType,
  data = {},
  prompt,
}: Omit<AdaptiveAiTriggerConfig, 'sectionSlug'>): Trigger.TriggerPayload | null => {
  if (resourceId == null) {
    return null;
  }

  const payload: Trigger.TriggerPayload = {
    trigger_type: triggerType,
    resource_id: resourceId,
    data,
  };

  if (hasAiTriggerPrompt(prompt)) {
    payload.prompt = prompt.trim();
  }

  return payload;
};

export const invokeAdaptiveAiTrigger = (config: AdaptiveAiTriggerConfig) => {
  if (!config.sectionSlug || !canInvokeAiTrigger()) {
    return Promise.resolve(null);
  }

  const payload = buildAdaptiveAiTriggerPayload(config);
  if (!payload) {
    return Promise.resolve(null);
  }

  return Trigger.invoke(config.sectionSlug, payload);
};
