import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import MatchingItemContent from './MatchingItemContent';
import MatchingLines from './MatchingLines';
import {
  DrawnLine,
  areDrawnLinesEqual,
  buildDrawnLines,
  columnTitle,
  isLinkCorrect,
  isPairMatched,
  itemDisplayText,
  itemLabel,
  toggleMatch,
} from './matching-util';
import { DEFAULT_MATCHING_THEME, MatchingItem, MatchingMatches, MatchingModel } from './schema';

export interface MatchingBoardProps {
  model: MatchingModel;
  matches: MatchingMatches;
  onMatchesChange: (next: MatchingMatches) => void;
  enabled: boolean;
  showHints: boolean;
}

type FocusZone = 'col1' | 'col2';

const MatchingBoard: React.FC<MatchingBoardProps> = ({
  model,
  matches,
  onMatchesChange,
  enabled,
  showHints,
}) => {
  const stageRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const liveRegionRef = useRef<HTMLSpanElement>(null);

  const [lines, setLines] = useState<DrawnLine[]>([]);
  const [draft, setDraft] = useState<{ x1: number; y1: number; x2: number; y2: number } | null>(
    null,
  );
  const [selectedCol1Id, setSelectedCol1Id] = useState<string | null>(null);
  const [focusedItemId, setFocusedItemId] = useState<string | null>(null);
  const [focusZone, setFocusZone] = useState<FocusZone>('col1');
  const [draggingFromId, setDraggingFromId] = useState<string | null>(null);

  const column1Items = model.column1Items || [];
  const column2Items = model.column2Items || [];
  const showTitles = model.showColumnTitles !== false;
  const themeColor = model.themeColor || DEFAULT_MATCHING_THEME;

  const announce = useCallback((message: string) => {
    if (!liveRegionRef.current) {
      return;
    }
    liveRegionRef.current.textContent = message;
    setTimeout(() => {
      if (liveRegionRef.current) {
        liveRegionRef.current.textContent = '';
      }
    }, 600);
  }, []);

  const focusItem = useCallback((itemId: string) => {
    const el = itemRefs.current[itemId];
    if (!el) {
      return;
    }
    try {
      el.focus({ preventScroll: true, focusVisible: true } as FocusOptions);
    } catch (_err) {
      el.focus();
    }
    setFocusedItemId(itemId);
  }, []);

  const redrawLines = useCallback(() => {
    if (!stageRef.current) {
      setLines((prev) => (prev.length === 0 ? prev : []));
      return;
    }
    const stageRect = stageRef.current.getBoundingClientRect();
    const next = buildDrawnLines(matches, (itemId, side) => {
      const el = itemRefs.current[itemId];
      if (!el) {
        return null;
      }
      const rect = el.getBoundingClientRect();
      return {
        x: side === 'left' ? rect.right - stageRect.left : rect.left - stageRect.left,
        y: (rect.top + rect.bottom) / 2 - stageRect.top,
      };
    });
    setLines((prev) => (areDrawnLinesEqual(prev, next) ? prev : next));
  }, [matches]);

  useLayoutEffect(() => {
    redrawLines();
  }, [redrawLines, matches, showTitles, showHints, column1Items.length, column2Items.length]);

  useEffect(() => {
    window.addEventListener('resize', redrawLines);
    return () => window.removeEventListener('resize', redrawLines);
  }, [redrawLines]);

  const applyToggle = useCallback(
    (col1Item: MatchingItem, col2Item: MatchingItem) => {
      const wasMatched = isPairMatched(matches, col1Item.id, col2Item.id);
      const next = toggleMatch(matches, col1Item, col2Item);
      onMatchesChange(next);
      announce(
        wasMatched
          ? `Removed match between ${itemLabel(col1Item, 0)} and ${itemLabel(col2Item, 0)}`
          : `Matched ${itemLabel(col1Item, 0)} with ${itemLabel(col2Item, 0)}`,
      );
      return next;
    },
    [announce, matches, onMatchesChange],
  );

  const getStagePoint = (clientX: number, clientY: number) => {
    if (!stageRef.current) {
      return { x: 0, y: 0 };
    }
    const rect = stageRef.current.getBoundingClientRect();
    return { x: clientX - rect.left, y: clientY - rect.top };
  };

  const startDrag = (col1Id: string, clientX: number, clientY: number) => {
    if (!enabled) {
      return;
    }
    const el = itemRefs.current[col1Id];
    if (!el || !stageRef.current) {
      return;
    }
    const stageRect = stageRef.current.getBoundingClientRect();
    const rect = el.getBoundingClientRect();
    const start = {
      x: rect.right - stageRect.left,
      y: (rect.top + rect.bottom) / 2 - stageRect.top,
    };
    const point = getStagePoint(clientX, clientY);
    setDraggingFromId(col1Id);
    setSelectedCol1Id(col1Id);
    setDraft({ x1: start.x, y1: start.y, x2: point.x, y2: point.y });
  };

  useEffect(() => {
    if (!draggingFromId) {
      return;
    }

    const onMove = (e: PointerEvent) => {
      setDraft((prev) => {
        if (!prev) {
          return prev;
        }
        const point = getStagePoint(e.clientX, e.clientY);
        return { ...prev, x2: point.x, y2: point.y };
      });
    };

    const onUp = (e: PointerEvent) => {
      const target = document.elementFromPoint(e.clientX, e.clientY) as HTMLElement | null;
      const col2Id = target?.closest?.('[data-matching-col2]')?.getAttribute('data-item-id');
      const col1Item = column1Items.find((i) => i.id === draggingFromId);
      const col2Item = column2Items.find((i) => i.id === col2Id);
      if (col1Item && col2Item && enabled) {
        applyToggle(col1Item, col2Item);
      }
      setDraggingFromId(null);
      setDraft(null);
      setFocusZone('col1');
    };

    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
  }, [applyToggle, column1Items, column2Items, draggingFromId, enabled]);

  const handleCol1KeyDown = (e: React.KeyboardEvent, item: MatchingItem, index: number) => {
    if (!enabled) {
      return;
    }

    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      setSelectedCol1Id(item.id);
      setFocusZone('col2');
      announce(`Selected ${itemLabel(item, index)}. Choose a match from column 2.`);
      const firstCol2 = column2Items[0];
      if (firstCol2) {
        requestAnimationFrame(() => focusItem(firstCol2.id));
      }
      return;
    }

    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const nextIndex =
        e.key === 'ArrowDown'
          ? Math.min(column1Items.length - 1, index + 1)
          : Math.max(0, index - 1);
      focusItem(column1Items[nextIndex].id);
    }
  };

  const handleCol2KeyDown = (e: React.KeyboardEvent, item: MatchingItem, index: number) => {
    if (!enabled || !selectedCol1Id) {
      return;
    }

    if (e.key === 'Escape') {
      e.preventDefault();
      const col1Id = selectedCol1Id;
      setSelectedCol1Id(null);
      setFocusZone('col1');
      announce('Selection cancelled');
      requestAnimationFrame(() => focusItem(col1Id));
      return;
    }

    if (e.key === 'Tab') {
      e.preventDefault();
      const nextIndex = e.shiftKey
        ? (index - 1 + column2Items.length) % column2Items.length
        : (index + 1) % column2Items.length;
      focusItem(column2Items[nextIndex].id);
      return;
    }

    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      const col1Item = column1Items.find((i) => i.id === selectedCol1Id);
      if (!col1Item) {
        return;
      }
      applyToggle(col1Item, item);
      setSelectedCol1Id(null);
      setFocusZone('col1');
      requestAnimationFrame(() => focusItem(col1Item.id));
      return;
    }

    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const nextIndex =
        e.key === 'ArrowDown'
          ? Math.min(column2Items.length - 1, index + 1)
          : Math.max(0, index - 1);
      focusItem(column2Items[nextIndex].id);
    }
  };

  const itemHasMatch = (itemId: string, col: 1 | 2) => {
    if (col === 1) {
      return (matches[itemId] || []).length > 0;
    }
    return Object.values(matches).some((targets) => (targets || []).includes(itemId));
  };

  const itemHintClass = (itemId: string, col: 1 | 2): string => {
    if (!showHints) {
      return '';
    }
    if (col === 1) {
      const targets = matches[itemId] || [];
      if (targets.length === 0) {
        return '';
      }
      const allCorrect = targets.every((col2Id) => isLinkCorrect(model, matches, itemId, col2Id));
      return allCorrect ? 'is-correct' : 'is-incorrect';
    }
    const owners = Object.keys(matches).filter((c1) => (matches[c1] || []).includes(itemId));
    if (owners.length === 0) {
      return '';
    }
    const allCorrect = owners.every((c1) => isLinkCorrect(model, matches, c1, itemId));
    return allCorrect ? 'is-correct' : 'is-incorrect';
  };

  const lineClassName = (line: DrawnLine): string => {
    if (!showHints) {
      return '';
    }
    return isLinkCorrect(model, matches, line.col1Id, line.col2Id)
      ? 'matching-line--correct'
      : 'matching-line--incorrect';
  };

  return (
    <div className="matching-stage" ref={stageRef}>
      <MatchingLines
        lines={lines}
        draft={draft}
        themeColor={themeColor}
        getLineClassName={lineClassName}
        onLineClick={
          enabled
            ? (line) => {
                const col1Item = column1Items.find((i) => i.id === line.col1Id);
                const col2Item = column2Items.find((i) => i.id === line.col2Id);
                if (col1Item && col2Item) {
                  applyToggle(col1Item, col2Item);
                }
              }
            : undefined
        }
      />
      <div className="matching-columns">
        <section
          className="matching-column"
          aria-label={columnTitle(model.column1Title, 'Column 1')}
        >
          {showTitles && (
            <header className="matching-column-header">
              <span>{columnTitle(model.column1Title, 'Column 1')}</span>
              <span className="matching-column-badge">Col 1</span>
            </header>
          )}
          <div className="matching-items" role="list">
            {column1Items.map((item, index) => {
              const selected = selectedCol1Id === item.id;
              const tabIndex = focusZone === 'col1' || !selectedCol1Id ? 0 : -1;
              return (
                <button
                  key={item.id}
                  type="button"
                  role="listitem"
                  data-item-id={item.id}
                  data-matching-col1=""
                  ref={(el) => {
                    itemRefs.current[item.id] = el;
                  }}
                  className={[
                    'matching-item',
                    enabled ? 'is-interactive' : '',
                    selected ? 'is-selected' : '',
                    focusedItemId === item.id ? 'is-focused' : '',
                    itemHasMatch(item.id, 1) ? 'is-matched' : '',
                    itemHintClass(item.id, 1),
                  ]
                    .filter(Boolean)
                    .join(' ')}
                  tabIndex={enabled ? tabIndex : -1}
                  disabled={!enabled}
                  aria-label={`${itemLabel(item, index)}. ${itemDisplayText(
                    item,
                  )}. Press Enter to select and choose a match.`}
                  aria-pressed={selected}
                  onPointerDown={(e) => {
                    if (!enabled || e.button !== 0) {
                      return;
                    }
                    e.preventDefault();
                    startDrag(item.id, e.clientX, e.clientY);
                  }}
                  onKeyDown={(e) => handleCol1KeyDown(e, item, index)}
                  onFocus={() => {
                    setFocusZone('col1');
                    setFocusedItemId(item.id);
                  }}
                  onBlur={() => {
                    setFocusedItemId((prev) => (prev === item.id ? null : prev));
                  }}
                >
                  <div className="matching-item-body">
                    <MatchingItemContent item={item} />
                  </div>
                </button>
              );
            })}
          </div>
        </section>

        <section
          className="matching-column"
          aria-label={columnTitle(model.column2Title, 'Column 2')}
        >
          {showTitles && (
            <header className="matching-column-header">
              <span>{columnTitle(model.column2Title, 'Column 2')}</span>
              <span className="matching-column-badge">Col 2</span>
            </header>
          )}
          <div className="matching-items" role="list">
            {column2Items.map((item, index) => {
              const tabIndex = focusZone === 'col2' && selectedCol1Id ? 0 : -1;
              return (
                <button
                  key={item.id}
                  type="button"
                  role="listitem"
                  data-item-id={item.id}
                  data-matching-col2=""
                  ref={(el) => {
                    itemRefs.current[item.id] = el;
                  }}
                  className={[
                    'matching-item',
                    enabled && selectedCol1Id ? 'is-interactive' : '',
                    focusedItemId === item.id ? 'is-focused' : '',
                    itemHasMatch(item.id, 2) ? 'is-matched' : '',
                    itemHintClass(item.id, 2),
                  ]
                    .filter(Boolean)
                    .join(' ')}
                  tabIndex={enabled ? tabIndex : -1}
                  disabled={!enabled}
                  aria-label={`${itemLabel(item, index)}. ${itemDisplayText(
                    item,
                  )}. Press Enter to match with the selected item.`}
                  onClick={() => {
                    if (!enabled || !selectedCol1Id) {
                      return;
                    }
                    const col1Item = column1Items.find((i) => i.id === selectedCol1Id);
                    if (!col1Item) {
                      return;
                    }
                    applyToggle(col1Item, item);
                    setSelectedCol1Id(null);
                    setFocusZone('col1');
                    requestAnimationFrame(() => focusItem(col1Item.id));
                  }}
                  onKeyDown={(e) => handleCol2KeyDown(e, item, index)}
                  onFocus={() => {
                    setFocusedItemId(item.id);
                  }}
                  onBlur={() => {
                    setFocusedItemId((prev) => (prev === item.id ? null : prev));
                  }}
                >
                  <div className="matching-item-body">
                    <MatchingItemContent item={item} />
                  </div>
                </button>
              );
            })}
          </div>
        </section>
      </div>
      <span className="matching-sr-only" aria-live="polite" ref={liveRegionRef} />
    </div>
  );
};

export default MatchingBoard;
