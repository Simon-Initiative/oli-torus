import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import './Matching.scss';
import MatchingBoard from './MatchingBoard';
import {
  buildResponses,
  correctMatchesSnapshot,
  matchingContainerStyles,
  matchingLayoutClass,
  matchingMinHeight,
  matchingThemeStyles,
  normalizeMatchingItemsForSave,
  restoreMatches,
  shuffleItems,
} from './matching-util';
import { MatchingMatches, MatchingModel } from './schema';

const normalizeMatchingModel = (raw: Partial<MatchingModel>): MatchingModel =>
  ({
    ...raw,
    column1Items: normalizeMatchingItemsForSave(raw.column1Items || []),
    column2Items: normalizeMatchingItemsForSave(raw.column2Items || []),
    correctMatches: raw.correctMatches || {},
  } as MatchingModel);

const parseBool = (val: any): boolean => {
  if (typeof val === 'boolean') {
    return val;
  }
  if (typeof val === 'string') {
    return val.toLowerCase() === 'true';
  }
  return !!val;
};

const Matching: React.FC<PartComponentProps<MatchingModel>> = (props) => {
  const [_state, setState] = useState<any>([]);
  const [model, setModel] = useState<Partial<MatchingModel>>({});
  const [ready, setReady] = useState<boolean>(false);

  const [matches, setMatches] = useState<MatchingMatches>({});
  const [enabled, setEnabled] = useState<boolean>(true);
  const [showCorrect, setShowCorrect] = useState<boolean>(false);
  const [showHints, setShowHints] = useState<boolean>(false);
  const [userModified, setUserModified] = useState<boolean>(false);
  const [randomize, setRandomize] = useState<boolean>(true);

  const id: string = props.id;
  const containerRef = useRef<HTMLDivElement>(null);

  const initialize = useCallback(async (pModel: MatchingModel) => {
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : true;
    const dShowHints = typeof pModel.showHints === 'boolean' ? pModel.showHints : false;
    const dShowCorrect = typeof pModel.showCorrect === 'boolean' ? pModel.showCorrect : false;
    const dRandomize = typeof pModel.randomize === 'boolean' ? pModel.randomize : true;

    setEnabled(dEnabled);
    setShowHints(dShowHints);
    setShowCorrect(dShowCorrect);
    setRandomize(dRandomize);

    const initResult = await props.onInit({
      id,
      responses: buildResponses(
        pModel,
        {},
        {
          enabled: dEnabled,
          userModified: false,
          showCorrect: dShowCorrect,
          showHints: dShowHints,
          randomize: dRandomize,
        },
      ),
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

    const sRandomize = snapshot[`stage.${id}.randomize`];
    const nextRandomize = sRandomize !== undefined ? parseBool(sRandomize) : dRandomize;
    setRandomize(nextRandomize);

    const column1Items = nextRandomize
      ? shuffleItems(pModel.column1Items || [])
      : [...(pModel.column1Items || [])];
    const column2Items = nextRandomize
      ? shuffleItems(pModel.column2Items || [])
      : [...(pModel.column2Items || [])];
    setModel({ ...pModel, column1Items, column2Items });

    if (nextShowCorrect) {
      setMatches(correctMatchesSnapshot(pModel));
    } else {
      setMatches(restoreMatches(pModel, snapshot, id));
    }

    if (initResult.context.mode === contexts.REVIEW) {
      nextEnabled = false;
    }
    setEnabled(nextEnabled);
    setReady(true);
  }, []);

  useEffect(() => {
    let pModel: Partial<MatchingModel> | undefined;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
      } catch (_err) {
        // bad json
      }
    } else if (typeof props?.model === 'object' && props.model) {
      pModel = props.model;
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
    const normalized = normalizeMatchingModel(pModel);
    setModel(normalized);
    initialize(normalized);
  }, [props.model, props.state, initialize]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  const { width, height } = model;
  const isResponsive = width === '100%' || (typeof width === 'string' && width.includes('%'));
  const minHeight = matchingMinHeight(width, height);

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
    model.column1Items,
    model.column2Items,
    matches,
    showHints,
  ]);

  const saveState = useCallback(
    (
      nextMatches: MatchingMatches,
      flags: {
        enabled: boolean;
        userModified: boolean;
        showCorrect: boolean;
        showHints: boolean;
        randomize: boolean;
      },
    ) => {
      props.onSave({
        id: `${id}`,
        responses: buildResponses(model as MatchingModel, nextMatches, flags),
      });
    },
    [id, model, props],
  );

  const handleMatchesChange = useCallback(
    (next: MatchingMatches) => {
      if (!enabled) {
        return;
      }
      setMatches(next);
      setUserModified(true);
      saveState(next, { enabled, userModified: true, showCorrect, showHints, randomize });
    },
    [enabled, showCorrect, showHints, randomize, saveState],
  );

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
          const correct = correctMatchesSnapshot(model as MatchingModel);
          setMatches(correct);
          saveState(correct, {
            enabled,
            userModified,
            showCorrect: true,
            showHints,
            randomize,
          });
        }
      }
    },
    [id, model, enabled, userModified, showHints, randomize, saveState],
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

  const customCss = (model as MatchingModel).customCss || '';
  const styles: CSSProperties = {
    ...matchingContainerStyles(model.width, model.height),
    ...matchingThemeStyles((model as MatchingModel).themeColor),
  };

  return ready ? (
    <div
      ref={containerRef}
      data-janus-type={tagName}
      className={`matching matching-delivery ${matchingLayoutClass(model.width)}`}
      style={styles}
    >
      {customCss ? <style>{customCss}</style> : null}
      <MatchingBoard
        model={model as MatchingModel}
        matches={matches}
        onMatchesChange={handleMatchesChange}
        enabled={enabled}
        showHints={showHints}
      />
    </div>
  ) : null;
};

export const tagName = 'janus-matching';

export default Matching;
