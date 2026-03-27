import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { AIIcon } from 'components/misc/AIIcon';
import {
  buildAdaptiveAiTriggerPayload,
  canInvokeAiTrigger,
  hasAiTriggerPrompt,
  invokeAdaptiveAiTrigger,
} from '../aiTrigger';
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
  const { model: modelProp, onInit, onReady } = props;
  // The custom element wrapper lowercases attribute names, so sectionSlug arrives as sectionslug
  const sectionSlug = (props as any).sectionslug ?? props.sectionSlug;
  const resourceId =
    (props as any).resourceid != null ? Number((props as any).resourceid) : props.resourceId;

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

    const observerConfig = {
      attributes: true,
      attributeFilter: ['id'],
      childList: true,
      subtree: true,
    };

    const observer = new MutationObserver(refreshTriggerAvailability);
    observer.observe(document.body, observerConfig);

    // In adaptive delivery the component runs inside an iframe while
    // the DOT dialogue window lives in the parent frame. Observe the
    // parent body as well so we detect late-mounting #ai_bot.
    let parentObserver: MutationObserver | undefined;
    try {
      const isInIframe = window.parent !== window;
      const parentBody = isInIframe ? window.parent.document.body : null;
      if (parentBody) {
        parentObserver = new MutationObserver(refreshTriggerAvailability);
        parentObserver.observe(parentBody, observerConfig);
      }
    } catch (_e) {
      // Cross-origin access denied — ignore.
    }

    return () => {
      observer.disconnect();
      parentObserver?.disconnect();
    };
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
      resourceId == null ||
      !sectionSlug ||
      !triggerAvailable
    ) {
      return;
    }

    const timeout = window.setTimeout(() => {
      const payload = buildAdaptiveAiTriggerPayload({
        resourceId,
        triggerType: 'adaptive_page',
        data: {
          component_id: id,
          component_type: tagName,
        },
      });

      if (!payload || !canInvokeAiTrigger()) {
        return;
      }

      firedAutoTrigger.current = true;
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
    id,
    launchMode,
    prompt,
    resourceId,
    sectionSlug,
    ready,
    triggerAvailable,
  ]);

  if (!ready || launchMode !== 'click' || !hasAiTriggerPrompt(prompt) || !triggerAvailable) {
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
