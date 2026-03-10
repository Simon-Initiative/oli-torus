import * as Trigger from 'data/persistence/trigger';
import { SectionSlug } from 'data/types';

export type AdaptiveAiTriggerType = 'adaptive_page' | 'adaptive_component';

export interface AdaptiveAiTriggerConfig {
  sectionSlug?: SectionSlug;
  resourceId?: number;
  prompt?: string | null;
  triggerType: AdaptiveAiTriggerType;
  data?: Record<string, unknown>;
}

export const hasAiTriggerPrompt = (prompt?: string | null): prompt is string =>
  Boolean(prompt?.trim());

export const canInvokeAiTrigger = () => Boolean(Trigger.getInstanceId());

export const buildAdaptiveAiTriggerPayload = ({
  resourceId,
  prompt,
  triggerType,
  data = {},
}: Omit<AdaptiveAiTriggerConfig, 'sectionSlug'>): Trigger.TriggerPayload | null => {
  if (resourceId == null || !hasAiTriggerPrompt(prompt)) {
    return null;
  }

  return {
    trigger_type: triggerType,
    resource_id: resourceId,
    data,
    prompt: prompt.trim(),
  };
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
