import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import GroupingBoard from './GroupingBoard';
import './Grouping.scss';
import {
  BANK_ID,
  Placements,
  buildResponses,
  correctPlacements,
  groupingContainerStyles,
  groupingLayoutClass,
  groupingMinHeight,
  groupingThemeStyles,
  isResponsiveGroupingLayout,
  restorePlacements,
} from './grouping-util';
import { GroupingModel } from './schema';

const Grouping: React.FC<PartComponentProps<GroupingModel>> = (props) => {
  const [_state, setState] = useState<any>([]);
  const [model, setModel] = useState<Partial<GroupingModel>>({});
  const [ready, setReady] = useState<boolean>(false);

  const [placements, setPlacements] = useState<Placements>({});
  const [enabled, setEnabled] = useState<boolean>(true);
  const [showCorrect, setShowCorrect] = useState<boolean>(false);
  const [showHints, setShowHints] = useState<boolean>(false);
  const [userModified, setUserModified] = useState<boolean>(false);

  const id: string = props.id;
  const containerRef = useRef<HTMLDivElement>(null);

  const initialize = useCallback(async (pModel: GroupingModel) => {
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : true;
    const dShowHints = typeof pModel.showHints === 'boolean' ? pModel.showHints : false;
    const dShowCorrect = typeof pModel.showCorrect === 'boolean' ? pModel.showCorrect : false;

    setEnabled(dEnabled);
    setShowHints(dShowHints);
    setShowCorrect(dShowCorrect);

    const initResult = await props.onInit({
      id,
      responses: buildResponses(pModel, {}, {
        enabled: dEnabled,
        userModified: false,
        showCorrect: dShowCorrect,
        showHints: dShowHints,
      }),
    });

    const snapshot = initResult.snapshot || {};

    const sEnabled = snapshot[`stage.${id}.enabled`];
    let nextEnabled = sEnabled !== undefined ? sEnabled : dEnabled;

    const sShowHints = snapshot[`stage.${id}.showHints`];
    if (sShowHints !== undefined) {
      setShowHints(sShowHints);
    }

    const sShowCorrect = snapshot[`stage.${id}.showCorrect`];
    let nextShowCorrect = dShowCorrect;
    if (sShowCorrect !== undefined) {
      nextShowCorrect = sShowCorrect;
      setShowCorrect(sShowCorrect);
    }

    // Restore placements: Show Answer wins, otherwise rebuild from snapshot.
    if (nextShowCorrect) {
      setPlacements(correctPlacements(pModel));
    } else {
      setPlacements(restorePlacements(pModel, snapshot, id));
    }

    if (initResult.context.mode === contexts.REVIEW) {
      nextEnabled = false;
    }
    setEnabled(nextEnabled);

    setReady(true);
  }, []);

  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (_err) {
        // bad json
      }
    } else if (typeof props?.model === 'object') {
      pModel = props.model;
      setModel(pModel);
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (_err) {
        // bad json
      }
    }
    if (!pModel) {
      return;
    }
    initialize(pModel);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  const { width, height } = model;
  const isResponsive = isResponsiveGroupingLayout(width);
  const minHeight = groupingMinHeight(width, height);

  useEffect(() => {
    const styleChanges: Record<string, { value: number | string }> = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (!isResponsive && height !== undefined) {
      styleChanges.height = { value: height as number };
    } else if (isResponsive) {
      styleChanges.height = { value: minHeight };
    }
    if (Object.keys(styleChanges).length > 0) {
      props.onResize({ id: `${id}`, settings: styleChanges });
    }
  }, [width, height, isResponsive, minHeight, id]);

  useEffect(() => {
    if (!ready || !isResponsive || !containerRef.current) {
      return;
    }
    const el = containerRef.current;
    const reportHeight = () => {
      const contentHeight = Math.ceil(el.getBoundingClientRect().height);
      props.onResize({
        id: `${id}`,
        settings: { height: { value: Math.max(minHeight, contentHeight) } },
      });
    };
    reportHeight();
    const observer = new ResizeObserver(reportHeight);
    observer.observe(el);
    return () => observer.disconnect();
  }, [
    ready,
    isResponsive,
    minHeight,
    id,
    model.items,
    model.categories,
    placements,
    showHints,
  ]);

  const saveState = useCallback(
    (
      nextPlacements: Placements,
      flags: { enabled: boolean; userModified: boolean; showCorrect: boolean; showHints: boolean },
    ) => {
      props.onSave({
        id: `${id}`,
        responses: buildResponses(model as GroupingModel, nextPlacements, flags),
      });
    },
    [id, model, props],
  );

  const handleMove = useCallback(
    (itemId: string, zoneId: string) => {
      if (!enabled) {
        return;
      }
      setPlacements((prev) => {
        const next: Placements = { ...prev };
        if (zoneId === BANK_ID) {
          delete next[itemId];
        } else {
          next[itemId] = zoneId;
        }
        setUserModified(true);
        saveState(next, { enabled, userModified: true, showCorrect, showHints });
        return next;
      });
    },
    [enabled, showCorrect, showHints, saveState],
  );

  // Reacts to adaptivity rule mutations of enabled / showCorrect / showHints.
  const applyStateChanges = useCallback(
    (changes: Record<string, any>) => {
      const sEnabled = changes[`stage.${id}.enabled`];
      if (sEnabled !== undefined) {
        setEnabled(parseBool(sEnabled));
      }
      const sShowHints = changes[`stage.${id}.showHints`];
      if (sShowHints !== undefined) {
        setShowHints(parseBool(sShowHints));
      }
      const sShowCorrect = changes[`stage.${id}.showCorrect`];
      if (sShowCorrect !== undefined) {
        const show = parseBool(sShowCorrect);
        setShowCorrect(show);
        if (show) {
          const correct = correctPlacements(model as GroupingModel);
          setPlacements(correct);
          saveState(correct, {
            enabled,
            userModified,
            showCorrect: true,
            showHints,
          });
        }
      }
    },
    [id, model, enabled, userModified, showHints, saveState],
  );

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
          case NotificationType.CHECK_COMPLETE:
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              if (changes) {
                applyStateChanges(changes);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts: changes } = payload;
              if (changes) {
                applyStateChanges(changes);
              }
              if (payload.mode === contexts.REVIEW) {
                setEnabled(false);
              }
            }
            break;
        }
      };
      return subscribeToNotification(props.notify, notificationType, handler);
    });
    return () => {
      notifications.forEach((unsub) => unsub());
    };
  }, [props.notify, applyStateChanges]);

  const customCss = (model as GroupingModel).customCss || '';
  const styles: CSSProperties = {
    ...groupingContainerStyles(model.width, model.height),
    ...groupingThemeStyles((model as GroupingModel).themeColor),
  };

  return ready ? (
    <div
      ref={containerRef}
      data-janus-type={tagName}
      className={`grouping grouping-delivery ${groupingLayoutClass(model.width)}`}
      style={styles}
    >
      {customCss ? <style>{customCss}</style> : null}
      <GroupingBoard
        model={model as GroupingModel}
        placements={placements}
        onMove={handleMove}
        enabled={enabled}
        showHints={showHints}
      />
    </div>
  ) : null;
};

const parseBool = (val: any): boolean => {
  if (typeof val === 'boolean') {
    return val;
  }
  if (typeof val === 'string') {
    return val.toLowerCase() === 'true';
  }
  return !!val;
};

export const tagName = 'janus-item-bank';

export default Grouping;
