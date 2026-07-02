/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import './ListSort.scss';
import {
  buildFocusAnnouncement,
  buildItemAccessibleName,
  buildPositionAnnouncement,
  LIST_SORT_INSTRUCTIONS,
} from './list-sort-a11y';
import { correctOrderItems, isItemInCorrectPosition, itemBarStyle } from './list-sort-util';
import { DEFAULT_LIST_SORT_BAR_COLOR, ListSortItem, ListSortModel } from './schema';

const HintBadge: React.FC<{ type: 'correct' | 'incorrect' }> = ({ type }) => (
  <span className={`list-sort__hint list-sort__hint--${type}`} aria-hidden="true">
    <svg viewBox="0 0 12 12" width="12" height="12" focusable="false" aria-hidden="true">
      {type === 'correct' ? (
        <path
          d="M2.5 6.25 4.75 8.5 9.5 3.75"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.75"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      ) : (
        <>
          <path
            d="M3.5 3.5 8.5 8.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.75"
            strokeLinecap="round"
          />
          <path
            d="M8.5 3.5 3.5 8.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.75"
            strokeLinecap="round"
          />
        </>
      )}
    </svg>
  </span>
);

const shuffle = <T,>(input: T[]): T[] => {
  const arr = [...input];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
};

const isSelectKey = (e: React.KeyboardEvent) => {
  const key = e.key;
  const keyCode = e.keyCode ?? (e as React.KeyboardEvent & { which?: number }).which;
  return (
    key === 'Enter' ||
    key === ' ' ||
    key === 'Space' ||
    key === 'Spacebar' ||
    keyCode === 13 ||
    keyCode === 32
  );
};

const ListSort: React.FC<PartComponentProps<ListSortModel>> = (props) => {
  const [_state, setState] = useState<unknown>([]);
  const [model, setModel] = useState<Partial<ListSortModel>>({});
  const [ready, setReady] = useState<boolean>(false);

  const id: string = props.id;

  const [items, setItems] = useState<ListSortItem[]>([]);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [focusedIndex, setFocusedIndex] = useState<number | null>(null);
  const [draggingIndex, setDraggingIndex] = useState<number | null>(null);
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const [enabled, setEnabled] = useState(true);
  const [showAnswer, setShowAnswer] = useState(false);
  const [showHints, setShowHints] = useState(false);
  const [barColor, setBarColor] = useState(DEFAULT_LIST_SORT_BAR_COLOR);
  const [customCss, setCustomCss] = useState('');

  const correctIdsRef = React.useRef<string[]>([]);
  const itemsRef = React.useRef<ListSortItem[]>([]);
  const itemRefs = React.useRef<(HTMLDivElement | null)[]>([]);
  const liveRegionRef = React.useRef<HTMLSpanElement>(null);
  const pendingFocusIndexRef = React.useRef<number | null>(null);
  const skipBlurDeselectRef = React.useRef(false);
  const skipFocusAnnounceRef = React.useRef(false);

  const instructionsId = `${id}-list-sort-instructions`;

  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  useEffect(() => {
    if (pendingFocusIndexRef.current === null) {
      return;
    }
    const focusIndex = pendingFocusIndexRef.current;
    const el = itemRefs.current[focusIndex];
    if (el) {
      skipBlurDeselectRef.current = true;
      skipFocusAnnounceRef.current = true;
      setFocusedIndex(focusIndex);
      el.focus();
    }
    pendingFocusIndexRef.current = null;
  }, [items]);

  const announce = useCallback((message: string) => {
    if (!liveRegionRef.current) {
      return;
    }
    liveRegionRef.current.textContent = message;
    setTimeout(() => {
      if (liveRegionRef.current) {
        liveRegionRef.current.textContent = '';
      }
    }, 500);
  }, []);

  const isCorrect = useCallback(
    (current: ListSortItem[]) =>
      current.length === correctIdsRef.current.length &&
      current.every((item, index) => item.id === correctIdsRef.current[index]),
    [],
  );

  const saveState = useCallback(
    (current: ListSortItem[]) => {
      props.onSave({
        id: `${id}`,
        responses: [
          { key: 'userModified', type: CapiVariableTypes.BOOLEAN, value: true },
          { key: 'correct', type: CapiVariableTypes.BOOLEAN, value: isCorrect(current) },
          {
            key: 'currentItemList',
            type: CapiVariableTypes.ARRAY,
            value: current.map((i) => i.text),
          },
        ],
      });
    },
    [id, isCorrect, props],
  );

  const applyCorrectOrder = useCallback(
    (persist = true) => {
      const correct = correctOrderItems(itemsRef.current, correctIdsRef.current);
      setItems(correct);
      if (persist) {
        props.onSave({
          id: `${id}`,
          responses: [
            { key: 'correct', type: CapiVariableTypes.BOOLEAN, value: true },
            {
              key: 'currentItemList',
              type: CapiVariableTypes.ARRAY,
              value: correct.map((i) => i.text),
            },
            { key: 'showAnswer', type: CapiVariableTypes.BOOLEAN, value: true },
          ],
        });
      }
      return correct;
    },
    [id, props],
  );

  const initialize = useCallback(
    async (pModel: Partial<ListSortModel>) => {
      const listItems: ListSortItem[] = Array.isArray(pModel.listItems) ? pModel.listItems : [];
      correctIdsRef.current = listItems.map((i) => i.id);

      const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : true;
      setEnabled(dEnabled);

      const dBarColor = pModel.barColor || DEFAULT_LIST_SORT_BAR_COLOR;
      setBarColor(dBarColor);

      const dCustomCss = pModel.customCss || '';
      setCustomCss(dCustomCss);

      const dShowHints = typeof pModel.showHints === 'boolean' ? pModel.showHints : false;
      setShowHints(dShowHints);

      const dRandomize = typeof pModel.randomize === 'boolean' ? pModel.randomize : true;
      const initialItems = dRandomize ? shuffle(listItems) : [...listItems];
      setItems(initialItems);

      const initResult = await props.onInit({
        id,
        responses: [
          { key: 'enabled', type: CapiVariableTypes.BOOLEAN, value: dEnabled },
          { key: 'userModified', type: CapiVariableTypes.BOOLEAN, value: false },
          { key: 'correct', type: CapiVariableTypes.BOOLEAN, value: isCorrect(initialItems) },
          { key: 'showAnswer', type: CapiVariableTypes.BOOLEAN, value: false },
          { key: 'showHints', type: CapiVariableTypes.BOOLEAN, value: dShowHints },
          { key: 'barColor', type: CapiVariableTypes.STRING, value: dBarColor },
          {
            key: 'currentItemList',
            type: CapiVariableTypes.ARRAY,
            value: initialItems.map((i) => i.text),
          },
          { key: 'customCss', type: CapiVariableTypes.STRING, value: dCustomCss },
        ],
      });

      const snapshot = initResult.snapshot;

      const sEnabled = snapshot[`stage.${id}.enabled`];
      if (sEnabled !== undefined) {
        setEnabled(parseBool(sEnabled));
      }
      const sBarColor = snapshot[`stage.${id}.barColor`];
      if (sBarColor !== undefined) {
        setBarColor(sBarColor);
      }
      const sCustomCss = snapshot[`stage.${id}.customCss`];
      if (sCustomCss !== undefined) {
        setCustomCss(sCustomCss);
      }

      const sShowHints = snapshot[`stage.${id}.showHints`];
      if (sShowHints !== undefined) {
        setShowHints(parseBool(sShowHints));
      }

      const sShowAnswer = snapshot[`stage.${id}.showAnswer`];
      const initShowAnswer = sShowAnswer !== undefined ? parseBool(sShowAnswer) : false;
      setShowAnswer(initShowAnswer);

      if (initShowAnswer) {
        const correct = correctOrderItems(initialItems, correctIdsRef.current);
        setItems(correct);
      } else {
        const sCurrentItemList = snapshot[`stage.${id}.currentItemList`];
        if (Array.isArray(sCurrentItemList) && sCurrentItemList.length) {
          const byText = new Map(listItems.map((item) => [item.text, item]));
          const restored = sCurrentItemList
            .map((text: string) => byText.get(text))
            .filter((item): item is ListSortItem => !!item);
          if (restored.length === listItems.length) {
            setItems(restored);
          }
        }
      }

      if (initResult.context.mode === contexts.REVIEW) {
        setEnabled(false);
      }
      setReady(true);
    },
    [id, isCorrect, props],
  );

  useEffect(() => {
    let pModel;
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
        setState(JSON.parse(props.state));
      } catch (_err) {
        // bad json
      }
    }
    if (!pModel) {
      return;
    }
    initialize(pModel);
  }, [props, initialize]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready, id, props]);

  const applyStateChanges = useCallback(
    (changes: Record<string, any>) => {
      const sEnabled = changes[`stage.${id}.enabled`];
      if (sEnabled !== undefined) {
        setEnabled(parseBool(sEnabled));
      }
      const sBarColor = changes[`stage.${id}.barColor`];
      if (sBarColor !== undefined) {
        setBarColor(sBarColor);
      }
      const sCustomCss = changes[`stage.${id}.customCss`];
      if (sCustomCss !== undefined) {
        setCustomCss(sCustomCss);
      }
      const sShowHints = changes[`stage.${id}.showHints`];
      if (sShowHints !== undefined) {
        setShowHints(parseBool(sShowHints));
      }
      const sShowAnswer = changes[`stage.${id}.showAnswer`];
      if (sShowAnswer !== undefined) {
        const answerShown = parseBool(sShowAnswer);
        setShowAnswer(answerShown);
        if (answerShown) {
          applyCorrectOrder(true);
        }
      }
    },
    [applyCorrectOrder, id],
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
              applyStateChanges(changes);
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts: changes } = payload;
              applyStateChanges(changes);
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

  const {
    width,
    height,
    showHeaderFooter = true,
    headerLabel = 'First',
    footerLabel = 'Last',
  } = model;

  useEffect(() => {
    const styleChanges: Record<string, { value: number }> = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height !== undefined) {
      styleChanges.height = { value: height as number };
    }
    if (Object.keys(styleChanges).length > 0) {
      props.onResize({ id: `${id}`, settings: styleChanges });
    }
  }, [width, height, id, props]);

  const interactive = enabled && !showAnswer;

  useEffect(() => {
    if (!interactive) {
      setSelectedIndex(null);
      setFocusedIndex(null);
    }
  }, [interactive]);

  const moveItem = useCallback(
    (fromIndex: number, toIndex: number): number | null => {
      const current = itemsRef.current;
      if (toIndex < 0 || toIndex >= current.length) {
        return null;
      }
      const next = Array.from(current);
      const [moved] = next.splice(fromIndex, 1);
      next.splice(toIndex, 0, moved);
      setItems(next);
      saveState(next);
      return toIndex;
    },
    [saveState],
  );

  const onDragStart = useCallback(
    (index: number) => (e: React.DragEvent<HTMLDivElement>) => {
      if (!interactive) {
        return;
      }
      setSelectedIndex(null);
      setDraggingIndex(index);
      e.dataTransfer.effectAllowed = 'move';
    },
    [interactive],
  );

  const onDragOver = useCallback(
    (index: number) => (e: React.DragEvent<HTMLDivElement>) => {
      if (!interactive || draggingIndex === null) {
        return;
      }
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      setHoveredIndex(index);
      if (draggingIndex === index) {
        return;
      }
      setItems((prev) => {
        const next = Array.from(prev);
        const [moved] = next.splice(draggingIndex, 1);
        next.splice(index, 0, moved);
        return next;
      });
      setDraggingIndex(index);
    },
    [interactive, draggingIndex],
  );

  const onDragEnd = useCallback(
    (e: React.DragEvent<HTMLDivElement>) => {
      const finalIndex = draggingIndex;
      if (finalIndex !== null) {
        saveState(itemsRef.current);
        const total = itemsRef.current.length;
        announce(buildPositionAnnouncement(finalIndex, total));
      }
      setDraggingIndex(null);
      setHoveredIndex(null);
      e.currentTarget.draggable = false;
    },
    [draggingIndex, saveState, announce],
  );

  const onItemMouseDown = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      if (interactive) {
        e.currentTarget.draggable = true;
      }
    },
    [interactive],
  );

  const onItemMouseUp = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    if (draggingIndex === null) {
      e.currentTarget.draggable = false;
    }
  }, [draggingIndex]);

  const onItemFocus = useCallback(
    (index: number, text: string, isSelected: boolean) => () => {
      setFocusedIndex(index);
      if (!interactive) {
        return;
      }
      if (skipFocusAnnounceRef.current) {
        skipFocusAnnounceRef.current = false;
        return;
      }
      announce(
        buildFocusAnnouncement(index, itemsRef.current.length, text, isSelected),
      );
    },
    [interactive, announce],
  );

  const onItemBlur = useCallback(
    (index: number) => () => {
      if (skipBlurDeselectRef.current) {
        skipBlurDeselectRef.current = false;
        return;
      }
      if (selectedIndex === index) {
        setSelectedIndex(null);
      }
      setFocusedIndex(null);
    },
    [selectedIndex],
  );

  const onItemKeyDown = useCallback(
    (index: number) => (e: React.KeyboardEvent<HTMLDivElement>) => {
      if (!interactive) {
        return;
      }

      if (isSelectKey(e)) {
        e.preventDefault();
        e.stopPropagation();
        setSelectedIndex(selectedIndex === index ? null : index);
        return;
      }

      if (e.key === 'Escape' && selectedIndex !== null) {
        e.preventDefault();
        e.stopPropagation();
        setSelectedIndex(null);
        return;
      }

      if (selectedIndex === null) {
        return;
      }

      if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') {
        return;
      }

      const target = e.key === 'ArrowUp' ? selectedIndex - 1 : selectedIndex + 1;
      const newIndex = moveItem(selectedIndex, target);
      if (newIndex === null) {
        return;
      }

      e.preventDefault();
      e.stopPropagation();
      setSelectedIndex(newIndex);
      setFocusedIndex(newIndex);
      skipFocusAnnounceRef.current = true;
      pendingFocusIndexRef.current = newIndex;
      announce(buildPositionAnnouncement(newIndex, itemsRef.current.length));
    },
    [interactive, selectedIndex, moveItem, announce],
  );

  const containerStyle: CSSProperties = {
    width: width ?? '100%',
    ...(height != null ? { height, minHeight: height } : {}),
    ['--list-sort-bar-color' as any]: barColor,
  };

  const rootClass = [
    'list-sort',
    !enabled ? 'list-sort--disabled' : '',
    showAnswer ? 'list-sort--show-answer' : '',
  ]
    .filter(Boolean)
    .join(' ');

  return ready ? (
    <div data-janus-type={tagName} className={rootClass} style={containerStyle}>
      {customCss ? <style>{customCss}</style> : null}
      {showHeaderFooter && <div className="list-sort__header">{headerLabel}</div>}
      <span id={instructionsId} className="sr-only">
        {LIST_SORT_INSTRUCTIONS}
      </span>
      <span
        ref={liveRegionRef}
        className="sr-only"
        role="status"
        aria-live="polite"
        aria-atomic="true"
      />
      <div className="list-sort__items" role="list">
        {items.map((item, index) => {
          const isDragging = draggingIndex === index;
          const isSelected = selectedIndex === index;
          const isFocused = focusedIndex === index;
          const isHovered = hoveredIndex === index && draggingIndex !== index;
          const inCorrectSlot = isItemInCorrectPosition(item.id, index, correctIdsRef.current);
          const hintClass = showHints
            ? inCorrectSlot
              ? 'list-sort__text--correct'
              : 'list-sort__text--incorrect'
            : '';
          return (
            <div
              key={item.id}
              ref={(el) => {
                itemRefs.current[index] = el;
              }}
              className={`list-sort__item ${isDragging ? 'list-sort__item--dragging' : ''} ${
                isHovered ? 'list-sort__item--hovered' : ''
              } ${isSelected ? 'list-sort__item--selected' : ''} ${
                isFocused ? 'list-sort__item--focused' : ''
              }`}
              style={itemBarStyle(barColor, index, items.length)}
              draggable={false}
              onMouseDown={onItemMouseDown}
              onMouseUp={onItemMouseUp}
              onDragStart={onDragStart(index)}
              onDragOver={onDragOver(index)}
              onDragEnd={onDragEnd}
              onDrop={(e) => e.preventDefault()}
              onKeyDown={onItemKeyDown(index)}
              onFocus={onItemFocus(index, item.text, isSelected)}
              onBlur={onItemBlur(index)}
              tabIndex={interactive ? 0 : undefined}
              role="listitem"
              aria-label={buildItemAccessibleName(item.text)}
              aria-grabbed={interactive ? isDragging || isSelected : undefined}
            >
              <span className="list-sort__bar" aria-hidden="true" />
              <div className={`list-sort__text ${hintClass}`}>
                {showHints && <HintBadge type={inCorrectSlot ? 'correct' : 'incorrect'} />}
                <span className="list-sort__text-label">{item.text}</span>
              </div>
            </div>
          );
        })}
      </div>
      {showHeaderFooter && <div className="list-sort__footer">{footerLabel}</div>}
    </div>
  ) : null;
};

export const tagName = 'janus-list-sort';

export default ListSort;
