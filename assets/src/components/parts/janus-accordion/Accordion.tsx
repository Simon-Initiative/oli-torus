import React, { useCallback, useEffect, useRef, useState } from 'react';
import { parseBoolean } from 'utils/common';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import AccordionView, { tagName } from './AccordionView';
import {
  AccordionCapiState,
  buildResponses,
  parseAccordionModel,
  parseSectionIndexes,
  uniqueSortedIndexes,
} from './accordion-util';
import { AccordionModel } from './schema';

const Accordion: React.FC<PartComponentProps<AccordionModel>> = (props) => {
  const id: string = props.id;
  const [model, setModel] = useState<AccordionModel | null>(null);
  const [ready, setReady] = useState(false);
  const [enabled, setEnabled] = useState(true);
  const [userOpened, setUserOpened] = useState(false);
  const [openedSections, setOpenedSections] = useState<number[]>([]);
  const [expandedSections, setExpandedSections] = useState<number[]>([]);
  const containerRef = useRef<HTMLDivElement>(null);

  const saveState = useCallback(
    (next: AccordionCapiState) => {
      props.onSave({
        id: `${id}`,
        responses: buildResponses(next),
      });
    },
    [id, props],
  );

  const initialize = useCallback(async (pModel: AccordionModel) => {
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : true;
    const sectionCount = pModel.sections.length;

    const initResult = await props.onInit({
      id,
      responses: buildResponses({
        enabled: dEnabled,
        userOpened: false,
        openedSections: [],
        expandedSections: [],
      }),
    });

    const snapshot = initResult.snapshot || {};
    let nextEnabled =
      snapshot[`stage.${id}.enabled`] !== undefined
        ? parseBoolean(snapshot[`stage.${id}.enabled`])
        : dEnabled;

    const nextExpanded = parseSectionIndexes(
      snapshot[`stage.${id}.expandedSections`],
      sectionCount,
    );
    const restoredOpened = parseSectionIndexes(
      snapshot[`stage.${id}.openedSections`],
      sectionCount,
    );
    const nextOpened = uniqueSortedIndexes([...restoredOpened, ...nextExpanded]);
    const nextUserOpened = parseBoolean(snapshot[`stage.${id}.userOpened`] ?? false);

    if (initResult.context?.mode === contexts.REVIEW) {
      nextEnabled = false;
    }

    setEnabled(nextEnabled);
    setExpandedSections(nextExpanded);
    setOpenedSections(nextOpened);
    setUserOpened(nextUserOpened);
    setReady(true);
  }, []);

  useEffect(() => {
    const parsed = parseAccordionModel(props.model);
    setModel(parsed);
    initialize(parsed);
  }, []);

  useEffect(() => {
    if (!ready) return;
    const parsed = parseAccordionModel(props.model);
    setModel(parsed);
  }, [props.model]);

  useEffect(() => {
    if (ready) {
      props.onReady({ id: `${id}` });
    }
  }, [ready]);

  const applyStateChanges = useCallback(
    (changes: Record<string, any>) => {
      if (!model) return;
      const sectionCount = model.sections.length;
      const prefix = `stage.${id}.`;
      let changed = false;
      let nextEnabled = enabled;
      let nextExpanded = expandedSections;

      if (changes[`${prefix}enabled`] !== undefined) {
        nextEnabled = parseBoolean(changes[`${prefix}enabled`]);
        changed = true;
      }
      if (changes[`${prefix}expandedSections`] !== undefined) {
        nextExpanded = parseSectionIndexes(changes[`${prefix}expandedSections`], sectionCount);
        changed = true;
      }

      if (changed) {
        setEnabled(nextEnabled);
        setExpandedSections(nextExpanded);
        const nextOpened = uniqueSortedIndexes([...openedSections, ...nextExpanded]);
        setOpenedSections(nextOpened);
        saveState({
          enabled: nextEnabled,
          userOpened,
          openedSections: nextOpened,
          expandedSections: nextExpanded,
        });
      }
    },
    [model, id, enabled, expandedSections, openedSections, userOpened, saveState],
  );

  useEffect(() => {
    if (!props.notify) return;
    const notificationsHandled = [
      NotificationType.STATE_CHANGED,
      NotificationType.CONTEXT_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType) => {
      const handler = (payload: any) => {
        if (notificationType === NotificationType.STATE_CHANGED) {
          applyStateChanges(payload.mutateChanges || {});
        }
        if (notificationType === NotificationType.CONTEXT_CHANGED) {
          applyStateChanges(payload.snapshot || payload.initStateFacts || {});
        }
      };
      return subscribeToNotification(props.notify, notificationType, handler);
    });
    return () => {
      notifications.forEach((unsub) => unsub());
    };
  }, [props.notify, applyStateChanges]);

  const handleToggle = useCallback(
    (sectionIndex: number) => {
      if (!enabled) return;
      const isOpen = expandedSections.includes(sectionIndex);
      const nextExpanded = isOpen
        ? expandedSections.filter((i) => i !== sectionIndex)
        : uniqueSortedIndexes([...expandedSections, sectionIndex]);
      const nextOpened = isOpen
        ? openedSections
        : uniqueSortedIndexes([...openedSections, sectionIndex]);
      const nextUserOpened = true;

      setExpandedSections(nextExpanded);
      setOpenedSections(nextOpened);
      setUserOpened(nextUserOpened);
      saveState({
        enabled,
        userOpened: nextUserOpened,
        openedSections: nextOpened,
        expandedSections: nextExpanded,
      });
    },
    [enabled, expandedSections, openedSections, saveState],
  );

  if (!ready || !model) return null;

  return (
    <AccordionView
      ref={containerRef}
      id={id}
      model={model}
      expandedSections={expandedSections}
      enabled={enabled}
      onToggle={handleToggle}
      className="janus-accordion-delivery"
    />
  );
};

export { tagName };
export default Accordion;
