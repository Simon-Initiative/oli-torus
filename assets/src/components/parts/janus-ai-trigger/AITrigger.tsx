import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { AIIcon } from 'components/misc/AIIcon';
import { invokeAdaptiveAiTrigger, canInvokeAiTrigger, hasAiTriggerPrompt } from '../aiTrigger';
import { PartComponentProps } from '../types/parts';
import { AITriggerModel } from './schema';

const AUTO_TRIGGER_DELAY_MS = 2000;

const AITrigger: React.FC<PartComponentProps<AITriggerModel>> = (props) => {
  const [model, setModel] = useState<Partial<AITriggerModel>>({});
  const [ready, setReady] = useState(false);
  const firedAutoTrigger = useRef(false);
  const id = props.id;

  useEffect(() => {
    let parsedModel: Partial<AITriggerModel> | undefined;

    if (typeof props.model === 'string') {
      try {
        parsedModel = JSON.parse(props.model);
      } catch (_error) {
        parsedModel = undefined;
      }
    } else {
      parsedModel = props.model;
    }

    if (!parsedModel) {
      return;
    }

    setModel(parsedModel);

    props
      .onInit({
        id,
        responses: [],
      })
      .then(() => setReady(true));
  }, [id, props]);

  useEffect(() => {
    if (!ready) {
      return;
    }

    props.onReady({ id, responses: [] });
  }, [id, props, ready]);

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
      !canInvokeAiTrigger()
    ) {
      return;
    }

    const timeout = window.setTimeout(() => {
      firedAutoTrigger.current = true;
      void invokeAdaptiveAiTrigger({
        sectionSlug: props.sectionSlug,
        resourceId: props.resourceId,
        prompt,
        triggerType: 'adaptive_page',
        data: {
          component_id: id,
        },
      });
    }, AUTO_TRIGGER_DELAY_MS);

    return () => window.clearTimeout(timeout);
  }, [id, launchMode, prompt, props.resourceId, props.sectionSlug, ready]);

  if (
    !ready ||
    launchMode !== 'click' ||
    !hasAiTriggerPrompt(prompt) ||
    !canInvokeAiTrigger()
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
      sectionSlug: props.sectionSlug,
      resourceId: props.resourceId,
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

export const tagName = 'janus-ai-trigger';

export default AITrigger;
