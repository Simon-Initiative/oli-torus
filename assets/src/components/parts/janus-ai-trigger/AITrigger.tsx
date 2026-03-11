import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { AIIcon } from 'components/misc/AIIcon';
import { invokeAdaptiveAiTrigger, canInvokeAiTrigger, hasAiTriggerPrompt } from '../aiTrigger';
import { PartComponentProps } from '../types/parts';
import { aiTriggerTagName } from './constants';
import { AITriggerModel } from './schema';

const AUTO_TRIGGER_DELAY_MS = 2000;
const AUTO_TRIGGER_SESSION_KEY_PREFIX = 'adaptive-ai-trigger:auto';

const buildAutoTriggerSessionKey = (
  sectionSlug?: string,
  resourceId?: number,
  componentId?: string,
) =>
  [AUTO_TRIGGER_SESSION_KEY_PREFIX, sectionSlug ?? 'unknown', resourceId ?? 'unknown', componentId]
    .join(':')
    .trim();

const hasAutoTriggerFiredInSession = (key: string) => {
  try {
    return window.sessionStorage.getItem(key) === 'true';
  } catch (_error) {
    return false;
  }
};

const markAutoTriggerFiredInSession = (key: string) => {
  try {
    window.sessionStorage.setItem(key, 'true');
  } catch (_error) {
    // Ignore storage failures and fall back to the in-memory guard.
  }
};

const AITrigger: React.FC<PartComponentProps<AITriggerModel>> = (props) => {
  const [model, setModel] = useState<Partial<AITriggerModel>>({});
  const [ready, setReady] = useState(false);
  const [triggerAvailable, setTriggerAvailable] = useState(() => canInvokeAiTrigger());
  const firedAutoTrigger = useRef(false);
  const id = props.id;
  const { model: modelProp, onInit, onReady, resourceId, sectionSlug } = props;

  useEffect(() => {
    let parsedModel: Partial<AITriggerModel> | undefined;

    if (typeof modelProp === 'string') {
      try {
        parsedModel = JSON.parse(modelProp);
      } catch (_error) {
        parsedModel = undefined;
      }
    } else {
      parsedModel = modelProp;
    }

    if (!parsedModel) {
      return;
    }

    setModel(parsedModel);

    onInit({
      id,
      responses: [],
    }).then(() => setReady(true));
  }, [id, modelProp, onInit]);

  useEffect(() => {
    if (!ready) {
      return;
    }

    onReady({ id, responses: [] });
  }, [id, onReady, ready]);

  useEffect(() => {
    const refreshTriggerAvailability = () => {
      setTriggerAvailable(canInvokeAiTrigger());
    };

    refreshTriggerAvailability();

    if (typeof MutationObserver === 'undefined' || !document.body) {
      return;
    }

    const observer = new MutationObserver(refreshTriggerAvailability);
    observer.observe(document.body, {
      attributes: true,
      attributeFilter: ['id'],
      childList: true,
      subtree: true,
    });

    return () => observer.disconnect();
  }, []);

  const {
    width = 56,
    height = 56,
    launchMode = 'click',
    prompt,
    ariaLabel = 'Open DOT AI assistant',
  } = model;
  const autoTriggerSessionKey = buildAutoTriggerSessionKey(sectionSlug, resourceId, id);

  useEffect(() => {
    if (
      !ready ||
      firedAutoTrigger.current ||
      launchMode !== 'auto' ||
      !hasAiTriggerPrompt(prompt) ||
      !triggerAvailable ||
      hasAutoTriggerFiredInSession(autoTriggerSessionKey)
    ) {
      return;
    }

    const timeout = window.setTimeout(() => {
      firedAutoTrigger.current = true;
      markAutoTriggerFiredInSession(autoTriggerSessionKey);
      void invokeAdaptiveAiTrigger({
        sectionSlug,
        resourceId,
        triggerType: 'adaptive_page',
        data: {
          component_id: id,
          component_type: tagName,
        },
      });
    }, AUTO_TRIGGER_DELAY_MS);

    return () => window.clearTimeout(timeout);
  }, [
    autoTriggerSessionKey,
    id,
    launchMode,
    prompt,
    resourceId,
    sectionSlug,
    ready,
    triggerAvailable,
  ]);

  if (
    !ready ||
    launchMode !== 'click' ||
    !hasAiTriggerPrompt(prompt) ||
    !triggerAvailable
  ) {
    return null;
  }

  const styles: CSSProperties = {
    width,
    minHeight: height,
    border: 'none',
    borderRadius: 9999,
    backgroundColor: '#E8F1FF',
    color: '#0F172A',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    padding: 10,
  };

  const handleClick = () =>
    invokeAdaptiveAiTrigger({
      sectionSlug,
      resourceId,
      triggerType: 'adaptive_component',
      data: {
        component_id: id,
        component_type: tagName,
      },
    });

  return (
    <button
      type="button"
      data-janus-type={tagName}
      aria-label={ariaLabel}
      title="Open DOT"
      onClick={() => void handleClick()}
      style={styles}
    >
      <AIIcon size="md" />
    </button>
  );
};

export const tagName = aiTriggerTagName;

export default AITrigger;
