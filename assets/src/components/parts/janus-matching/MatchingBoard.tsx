import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import MatchingItemContent from './MatchingItemContent';
import MatchingLines from './MatchingLines';
import {
  DrawnLine,
  MATCHING_INSTRUCTIONS,
  areDrawnLinesEqual,
  buildDrawnLines,
  buildMatchPairNumbers,
  columnTitle,
  isLinkCorrect,
  isPairMatched,
  itemAccessibleText,
  itemLabel,
  pairColorForNumber,
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

const MOBILE_MEDIA = '(max-width: 640px)';

const useIsMobileMatching = (): boolean => {
  const [isMobile, setIsMobile] = useState(() =>
    typeof window !== 'undefined' ? window.matchMedia(MOBILE_MEDIA).matches : false,
  );

  useEffect(() => {
    const media = window.matchMedia(MOBILE_MEDIA);
    const onChange = () => setIsMobile(media.matches);
    onChange();
    media.addEventListener('change', onChange);
    return () => media.removeEventListener('change', onChange);
  }, []);

  return isMobile;
};

const MatchingHintIcon: React.FC<{ type: 'correct' | 'incorrect' }> = ({ type }) => (
  <span className={`matching-hint matching-hint--${type}`} aria-hidden="true">
    {type === 'correct' ? (
      <svg viewBox="0 0 12 12" width="12" height="12" focusable="false" aria-hidden="true">
        <path
          d="M2.5 6.25 4.75 8.5 9.5 3.75"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.75"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    ) : (
      <span className="matching-hint__bang">!</span>
    )}
  </span>
);

const MatchingPairBadge: React.FC<{ pairNumber: number }> = ({ pairNumber }) => (
  <span
    className="matching-pair-badge"
    style={{ background: pairColorForNumber(pairNumber) }}
    aria-hidden="true"
  >
    {pairNumber}
  </span>
);

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
  const instructionsIdRef = useRef(
    `matching-instructions-${Math.random().toString(36).slice(2, 9)}`,
  );
  const instructionsId = instructionsIdRef.current;
  const isMobile = useIsMobileMatching();

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
  const pairNumbers = isMobile ? buildMatchPairNumbers(matches, column1Items) : {};

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

  const clearSelection = useCallback(() => {
    setSelectedCol1Id(null);
    setFocusZone('col1');
    setDraggingFromId(null);
    setDraft(null);
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
    if (!stageRef.current || isMobile) {
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
  }, [isMobile, matches]);

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
          ? `Removed match between ${itemAccessibleText(col1Item)} and ${itemAccessibleText(
              col2Item,
            )}`
          : `Matched ${itemAccessibleText(col1Item)} with ${itemAccessibleText(col2Item)}`,
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
    if (!enabled || isMobile) {
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
    if (!draggingFromId || isMobile) {
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
      clearSelection();
    };

    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
  }, [applyToggle, clearSelection, column1Items, column2Items, draggingFromId, enabled, isMobile]);

  useEffect(() => {
    if (!selectedCol1Id || draggingFromId) {
      return;
    }

    const onPointerDown = (e: PointerEvent) => {
      const stage = stageRef.current;
      if (!stage) {
        return;
      }
      if (e.target instanceof Node && stage.contains(e.target)) {
        return;
      }
      clearSelection();
    };

    window.addEventListener('pointerdown', onPointerDown);
    return () => window.removeEventListener('pointerdown', onPointerDown);
  }, [clearSelection, draggingFromId, selectedCol1Id]);

  const handleCol1KeyDown = (e: React.KeyboardEvent, item: MatchingItem, index: number) => {
    if (!enabled) {
      return;
    }

    if (e.key === 'Escape' && selectedCol1Id) {
      e.preventDefault();
      clearSelection();
      announce('Selection cancelled');
      return;
    }

    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      setSelectedCol1Id(item.id);
      setFocusZone('col2');
      announce(`Selected ${itemAccessibleText(item)}. Choose a match from column 2.`);
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
      clearSelection();
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
      clearSelection();
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

  const completeCol2Match = (item: MatchingItem) => {
    if (!enabled) {
      return;
    }
    if (selectedCol1Id) {
      const col1Item = column1Items.find((i) => i.id === selectedCol1Id);
      if (!col1Item) {
        return;
      }
      applyToggle(col1Item, item);
      clearSelection();
      requestAnimationFrame(() => focusItem(col1Item.id));
      return;
    }
    if (!isMobile || !itemHasMatch(item.id, 2)) {
      return;
    }
    const ownerId = Object.keys(matches).find((c1) => (matches[c1] || []).includes(item.id));
    const col1Item = ownerId ? column1Items.find((i) => i.id === ownerId) : undefined;
    if (!col1Item) {
      return;
    }
    applyToggle(col1Item, item);
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

  const hintTypeForItem = (itemId: string, col: 1 | 2): 'correct' | 'incorrect' | null => {
    const hintClass = itemHintClass(itemId, col);
    if (hintClass === 'is-correct') {
      return 'correct';
    }
    if (hintClass === 'is-incorrect') {
      return 'incorrect';
    }
    return null;
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
    <div
      className={`matching-stage${isMobile ? ' matching-stage--mobile' : ''}`}
      ref={stageRef}
      onBlur={(e) => {
        const next = e.relatedTarget as Node | null;
        if (next && e.currentTarget.contains(next)) {
          return;
        }
        requestAnimationFrame(() => {
          const active = document.activeElement;
          if (active && stageRef.current?.contains(active)) {
            return;
          }
          clearSelection();
        });
      }}
    >
      {!isMobile && (
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
      )}
      <p id={instructionsId} className="matching-sr-only">
        {MATCHING_INSTRUCTIONS}
      </p>
      <div className="matching-columns">
        <section
          className="matching-column"
          aria-label={columnTitle(model.column1Title, 'Column 1')}
        >
          {showTitles && (
            <header className="matching-column-header">
              <span>{columnTitle(model.column1Title, 'Column 1')}</span>
            </header>
          )}
          <div className="matching-items" role="list">
            {column1Items.map((item, index) => {
              const selected = selectedCol1Id === item.id;
              const tabIndex = focusZone === 'col1' || !selectedCol1Id ? 0 : -1;
              const hintType = hintTypeForItem(item.id, 1);
              const pairNumber = pairNumbers[item.id];
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
                  aria-label={`${itemLabel(item, index)}. ${itemAccessibleText(
                    item,
                  )}. Press Enter to select and choose a match.`}
                  aria-describedby={instructionsId}
                  aria-pressed={selected}
                  onPointerDown={(e) => {
                    if (!enabled || e.button !== 0 || isMobile) {
                      return;
                    }
                    e.preventDefault();
                    startDrag(item.id, e.clientX, e.clientY);
                  }}
                  onClick={() => {
                    if (!enabled || !isMobile) {
                      return;
                    }
                    setSelectedCol1Id((prev) => (prev === item.id ? null : item.id));
                    setFocusZone('col1');
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
                  {pairNumber ? <MatchingPairBadge pairNumber={pairNumber} /> : null}
                  {hintType ? <MatchingHintIcon type={hintType} /> : null}
                  <div className="matching-item-body" aria-hidden="true">
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
            </header>
          )}
          <div className="matching-items" role="list">
            {column2Items.map((item, index) => {
              const tabIndex = focusZone === 'col2' && selectedCol1Id ? 0 : -1;
              const hintType = hintTypeForItem(item.id, 2);
              const pairNumber = pairNumbers[item.id];
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
                    enabled && (selectedCol1Id || (isMobile && itemHasMatch(item.id, 2)))
                      ? 'is-interactive'
                      : '',
                    focusedItemId === item.id ? 'is-focused' : '',
                    itemHasMatch(item.id, 2) ? 'is-matched' : '',
                    itemHintClass(item.id, 2),
                  ]
                    .filter(Boolean)
                    .join(' ')}
                  tabIndex={enabled ? tabIndex : -1}
                  disabled={!enabled}
                  aria-label={`${itemLabel(item, index)}. ${itemAccessibleText(
                    item,
                  )}. Press Enter to match with the selected item.`}
                  aria-describedby={instructionsId}
                  onClick={() => completeCol2Match(item)}
                  onKeyDown={(e) => handleCol2KeyDown(e, item, index)}
                  onFocus={() => {
                    setFocusedItemId(item.id);
                  }}
                  onBlur={() => {
                    setFocusedItemId((prev) => (prev === item.id ? null : prev));
                  }}
                >
                  {pairNumber ? <MatchingPairBadge pairNumber={pairNumber} /> : null}
                  {hintType ? <MatchingHintIcon type={hintType} /> : null}
                  <div className="matching-item-body" aria-hidden="true">
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
