import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { AIIcon } from 'components/misc/AIIcon';
import { invokeAdaptiveAiTrigger, canInvokeAiTrigger, hasAiTriggerPrompt } from '../aiTrigger';
import { PartComponentProps } from '../types/parts';
import { aiTriggerTagName } from './constants';
import { AITriggerModel } from './schema';

const AUTO_TRIGGER_DELAY_MS = 2000;

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
      attributeFilter: ['data-dialogue-window', 'data-instance-id', 'id'],
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

  useEffect(() => {
    if (
      !ready ||
      firedAutoTrigger.current ||
      launchMode !== 'auto' ||
      !hasAiTriggerPrompt(prompt) ||
      !triggerAvailable
    ) {
      return;
    }

    const timeout = window.setTimeout(() => {
      firedAutoTrigger.current = true;
      void invokeAdaptiveAiTrigger({
        sectionSlug,
        resourceId,
        prompt,
        triggerType: 'adaptive_page',
        data: {
          component_id: id,
        },
      });
    }, AUTO_TRIGGER_DELAY_MS);

    return () => window.clearTimeout(timeout);
  }, [id, launchMode, prompt, resourceId, sectionSlug, ready, triggerAvailable]);

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
      prompt,
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
