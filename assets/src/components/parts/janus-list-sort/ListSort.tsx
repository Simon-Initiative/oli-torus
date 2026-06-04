/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import './ListSort.scss';
import { ListSortItem, ListSortModel } from './schema';

const shuffle = <T,>(input: T[]): T[] => {
  const arr = [...input];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
};

const orderById = (items: ListSortItem[], ids: string[]): ListSortItem[] => {
  const byId = new Map(items.map((item) => [item.id, item]));
  const ordered = ids.map((id) => byId.get(id)).filter((item): item is ListSortItem => !!item);
  // append any items that weren't represented in the id list (e.g. newly added)
  const missing = items.filter((item) => !ids.includes(item.id));
  return [...ordered, ...missing];
};

export const ListSortHandleIcon: React.FC = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M4 6h16v2H4zm0 5h16v2H4zm0 5h16v2H4z" />
  </svg>
);

const ListSort: React.FC<PartComponentProps<ListSortModel>> = (props) => {
  const [_state, setState] = useState<unknown>([]);
  const [model, setModel] = useState<Partial<ListSortModel>>({});
  const [ready, setReady] = useState<boolean>(false);

  const id: string = props.id;

  const [items, setItems] = useState<ListSortItem[]>([]);
  const [draggingIndex, setDraggingIndex] = useState<number | null>(null);
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const [enabled, setEnabled] = useState(true);
  const [showAnswer, setShowAnswer] = useState(false);
  const [barColor, setBarColor] = useState('#0070F3');
  const [customCss, setCustomCss] = useState('');

  // the author-defined correct order (ids), source of truth = listItems order
  const correctIdsRef = React.useRef<string[]>([]);
  // always holds the latest rendered order so drag-end can persist without stale closures
  const itemsRef = React.useRef<ListSortItem[]>([]);
  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  const isCorrect = useCallback(
    (current: ListSortItem[]) =>
      current.length === correctIdsRef.current.length &&
      current.every((item, index) => item.id === correctIdsRef.current[index]),
    [],
  );

  const initialize = useCallback(async (pModel: Partial<ListSortModel>) => {
    // listItems are authored in the correct order, so that order is the source of truth
    const listItems: ListSortItem[] = Array.isArray(pModel.listItems) ? pModel.listItems : [];
    correctIdsRef.current = listItems.map((i) => i.id);

    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : true;
    setEnabled(dEnabled);

    const dBarColor = pModel.barColor || '#0070F3';
    setBarColor(dBarColor);

    const dCustomCss = pModel.customCss || '';
    setCustomCss(dCustomCss);

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
      setEnabled(sEnabled);
    }
    const sBarColor = snapshot[`stage.${id}.barColor`];
    if (sBarColor !== undefined) {
      setBarColor(sBarColor);
    }
    const sCustomCss = snapshot[`stage.${id}.customCss`];
    if (sCustomCss !== undefined) {
      setCustomCss(sCustomCss);
    }
    const sShowAnswer = snapshot[`stage.${id}.showAnswer`];
    if (sShowAnswer !== undefined) {
      setShowAnswer(sShowAnswer);
    }
    const sCurrentItemList = snapshot[`stage.${id}.currentItemList`];
    if (Array.isArray(sCurrentItemList) && sCurrentItemList.length) {
      // hydrate the learner's saved order by matching on item text
      const byText = new Map(listItems.map((item) => [item.text, item]));
      const restored = sCurrentItemList
        .map((text: string) => byText.get(text))
        .filter((item): item is ListSortItem => !!item);
      if (restored.length === listItems.length) {
        setItems(restored);
      }
    }

    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }
    setReady(true);
  }, []);

  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // bad json, what do?
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

  const applyStateChanges = useCallback((changes: Record<string, any>) => {
    const sEnabled = changes[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setEnabled(sEnabled);
    }
    const sBarColor = changes[`stage.${id}.barColor`];
    if (sBarColor !== undefined) {
      setBarColor(sBarColor);
    }
    const sCustomCss = changes[`stage.${id}.customCss`];
    if (sCustomCss !== undefined) {
      setCustomCss(sCustomCss);
    }
    const sShowAnswer = changes[`stage.${id}.showAnswer`];
    if (sShowAnswer !== undefined) {
      setShowAnswer(sShowAnswer);
      if (sShowAnswer) {
        setItems((prev) => orderById(prev, correctIdsRef.current));
      }
    }
  }, [id]);

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
            break;
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
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify, applyStateChanges]);

  const { width, showHeaderFooter = true, headerLabel = 'First', footerLabel = 'Last' } = model;

  useEffect(() => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (model.height !== undefined) {
      styleChanges.height = { value: model.height as number };
    }
    props.onResize({ id: `${id}`, settings: styleChanges });
  }, [width, model.height]);

  const saveState = (current: ListSortItem[]) => {
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
  };

  // Native HTML5 drag-and-drop is used instead of react-beautiful-dnd because janus parts
  // render inside an absolutely-positioned (and on the authoring stage, scrolled/transformed)
  // container, which breaks rbd's fixed-position clone offset math. Native DnD is immune to that.
  const onDragStart = useCallback(
    (index: number) => (e: React.DragEvent<HTMLDivElement>) => {
      if (!enabled) {
        return;
      }
      setDraggingIndex(index);
      e.dataTransfer.effectAllowed = 'move';
    },
    [enabled],
  );

  const onDragOver = useCallback(
    (index: number) => (e: React.DragEvent<HTMLDivElement>) => {
      if (!enabled || draggingIndex === null) {
        return;
      }
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      setHoveredIndex(index);
      if (draggingIndex === index) {
        return;
      }
      // live reorder: move the dragged item to the hovered position as the cursor passes over it
      setItems((prev) => {
        const next = Array.from(prev);
        const [moved] = next.splice(draggingIndex, 1);
        next.splice(index, 0, moved);
        return next;
      });
      setDraggingIndex(index);
    },
    [enabled, draggingIndex],
  );

  const onDragEnd = useCallback(() => {
    if (draggingIndex !== null) {
      saveState(itemsRef.current);
    }
    setDraggingIndex(null);
    setHoveredIndex(null);
  }, [draggingIndex]);

  const onItemKeyDown = useCallback(
    (index: number) => (e: React.KeyboardEvent<HTMLDivElement>) => {
      if (!enabled || !e.getModifierState('Shift')) {
        return;
      }
      if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') {
        return;
      }
      const current = itemsRef.current;
      const target = e.key === 'ArrowUp' ? index - 1 : index + 1;
      if (target < 0 || target >= current.length) {
        return;
      }
      e.preventDefault();
      e.stopPropagation();
      const next = Array.from(current);
      const [moved] = next.splice(index, 1);
      next.splice(target, 0, moved);
      setItems(next);
      saveState(next);
    },
    [enabled],
  );

  const containerStyle: CSSProperties = {
    width: '100%',
    ['--list-sort-bar-color' as any]: barColor,
  };

  return ready ? (
    <div
      data-janus-type={tagName}
      className={`list-sort ${enabled ? '' : 'list-sort--disabled'}`}
      style={containerStyle}
    >
      {customCss ? <style>{customCss}</style> : null}
      {showHeaderFooter && <div className="list-sort__header">{headerLabel}</div>}
      <div className="list-sort__items" role="list">
        {items.map((item, index) => {
          const isDragging = draggingIndex === index;
          const isHovered = hoveredIndex === index && draggingIndex !== index;
          return (
            <div
              className={`list-sort__item ${isDragging ? 'list-sort__item--dragging' : ''} ${
                isHovered ? 'list-sort__item--hovered' : ''
              }`}
              draggable={enabled}
              onDragStart={onDragStart(index)}
              onDragOver={onDragOver(index)}
              onDragEnd={onDragEnd}
              onDrop={(e) => e.preventDefault()}
              onKeyDown={onItemKeyDown(index)}
              tabIndex={enabled ? 0 : undefined}
              role="listitem"
              aria-label={item.text}
              aria-grabbed={isDragging}
            >
              <span className="list-sort__bar" aria-hidden="true" />
              <span className="list-sort__handle" aria-hidden="true">
                <ListSortHandleIcon />
              </span>
              <span className="list-sort__text">{item.text}</span>
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
