import { CSSProperties } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { htmlToPlainText } from '../../../utils/richOptionLabel';
import {
  DEFAULT_MATCHING_MIN_HEIGHT,
  DEFAULT_MATCHING_THEME,
  MatchingItem,
  MatchingMatches,
  MatchingModel,
  RESPONSIVE_MATCHING_MIN_HEIGHT,
} from './schema';

export { DEFAULT_MATCHING_MIN_HEIGHT, DEFAULT_MATCHING_THEME, RESPONSIVE_MATCHING_MIN_HEIGHT };

export const isResponsiveMatchingLayout = (width?: number | string): boolean =>
  width === '100%' || (typeof width === 'string' && width.includes('%'));

export const matchingLayoutClass = (width?: number | string): string =>
  isResponsiveMatchingLayout(width) ? 'matching--responsive' : 'matching--fixed';

export const matchingMinHeight = (width?: number | string, height?: number): number => {
  if (isResponsiveMatchingLayout(width)) {
    return Math.max(RESPONSIVE_MATCHING_MIN_HEIGHT, height ?? RESPONSIVE_MATCHING_MIN_HEIGHT);
  }
  return height ?? DEFAULT_MATCHING_MIN_HEIGHT;
};

export const matchingThemeStyles = (themeColor?: string): CSSProperties => ({
  ['--matching-theme' as string]: themeColor || DEFAULT_MATCHING_THEME,
});

export const matchingContainerStyles = (
  width?: number | string,
  height?: number,
): CSSProperties => {
  const minHeight = matchingMinHeight(width, height);
  const cssVar = { ['--matching-min-height' as string]: `${minHeight}px` };

  if (isResponsiveMatchingLayout(width)) {
    return {
      width,
      minHeight,
      height: 'auto',
      ...cssVar,
    };
  }
  return {
    width,
    height: minHeight,
    ...cssVar,
  };
};

let idCounter = 0;
export const genId = (prefix: string): string => {
  idCounter += 1;
  return `${prefix}-${Date.now().toString(36)}-${idCounter}-${Math.random()
    .toString(36)
    .slice(2, 7)}`;
};

export const itemDisplayText = (item: MatchingItem): string =>
  (item.text && item.text.trim().length > 0 ? item.text : item.label) || '';

export const MATCHING_INSTRUCTIONS = 'Select an item, then choose a match from the other column.';

export const itemImageCaption = (item: MatchingItem): string => {
  if (item.type !== 'image' || item.text == null) {
    return '';
  }
  return item.text.trim();
};

/** Plain learner-facing text for aria-labels and announcements. */
export const itemAccessibleText = (item: MatchingItem): string => {
  if (item.type === 'image') {
    return item.alt?.trim() || htmlToPlainText(itemImageCaption(item)) || item.label?.trim() || '';
  }
  return htmlToPlainText(itemDisplayText(item));
};

export const shuffleItems = <T>(input: T[]): T[] => {
  const arr = [...input];
  for (let i = arr.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
};

export type MatchPairNumbers = Record<string, number>;

export const buildMatchPairNumbers = (
  matches: MatchingMatches,
  column1Items: MatchingItem[],
): MatchPairNumbers => {
  const numbers: MatchPairNumbers = {};
  let next = 1;
  column1Items.forEach((item) => {
    const targets = matches[item.id] || [];
    if (targets.length === 0) {
      return;
    }
    const pair = next;
    next += 1;
    numbers[item.id] = pair;
    targets.forEach((col2Id) => {
      numbers[col2Id] = pair;
    });
  });
  return numbers;
};

const PAIR_HUE_STEP = 137.508;

export const pairColorForNumber = (pairNumber: number): string => {
  const n = Math.max(1, Math.floor(pairNumber));
  const hue = ((n - 1) * PAIR_HUE_STEP) % 360;
  const lightness = 38 + ((n - 1) % 3) * 5;
  return `hsl(${hue.toFixed(1)} 72% ${lightness}%)`;
};

export const itemLabel = (item: MatchingItem, index: number): string =>
  (item?.label || '').trim() || `Item ${index + 1}`;

export const columnTitle = (title: string | undefined, fallback: string): string =>
  (title || '').trim() || fallback;

/** Ensure image items always carry an explicit `text` value for redux lodash merge saves. */
export const normalizeMatchingItemForSave = (item: MatchingItem): MatchingItem => {
  const maxLinks = Math.max(1, Math.min(10, Number(item.maxLinks) || 1));
  if (item.type !== 'image') {
    return { ...item, maxLinks };
  }
  return {
    ...item,
    maxLinks,
    text: (item.text || '').trim(),
  };
};

export const normalizeMatchingItemsForSave = (items: MatchingItem[]): MatchingItem[] =>
  items.map(normalizeMatchingItemForSave);

export const emptyMatches = (): MatchingMatches => ({});

export const cloneMatches = (matches: MatchingMatches): MatchingMatches => {
  const next: MatchingMatches = {};
  Object.keys(matches || {}).forEach((key) => {
    next[key] = [...(matches[key] || [])];
  });
  return next;
};

export const countMatches = (matches: MatchingMatches): number =>
  Object.values(matches || {}).reduce((sum, targets) => sum + (targets?.length || 0), 0);

export const isPairMatched = (matches: MatchingMatches, col1Id: string, col2Id: string): boolean =>
  (matches[col1Id] || []).includes(col2Id);

export const incomingMatchCount = (matches: MatchingMatches, col2Id: string): number =>
  Object.values(matches || {}).reduce(
    (sum, targets) => sum + (targets || []).filter((id) => id === col2Id).length,
    0,
  );

/**
 * Toggle a match between a column-1 item and a column-2 item, respecting
 * maxLinks on both ends. When at capacity, the oldest link is dropped
 * (FIFO) to make room for the new link.
 */
export const toggleMatch = (
  matches: MatchingMatches,
  col1Item: MatchingItem,
  col2Item: MatchingItem,
): MatchingMatches => {
  const next = cloneMatches(matches);
  const existing = next[col1Item.id] || [];

  if (existing.includes(col2Item.id)) {
    next[col1Item.id] = existing.filter((id) => id !== col2Item.id);
    if (next[col1Item.id].length === 0) {
      delete next[col1Item.id];
    }
    return next;
  }

  // Remove this col2 from any other col1 that already links to it if col2 is at capacity
  // after we would add (handled below with FIFO on col2 side by pruning others first when needed).

  const updated = [...existing];
  const max1 = Math.max(1, col1Item.maxLinks || 1);
  if (updated.length >= max1) {
    updated.shift();
  }
  updated.push(col2Item.id);
  next[col1Item.id] = updated;

  const max2 = Math.max(1, col2Item.maxLinks || 1);
  // Enforce col2 incoming limit by removing oldest links from other col1 items
  const owners: Array<{ col1Id: string; index: number }> = [];
  Object.keys(next).forEach((c1Id) => {
    (next[c1Id] || []).forEach((c2Id, index) => {
      if (c2Id === col2Item.id) {
        owners.push({ col1Id: c1Id, index });
      }
    });
  });
  while (owners.length > max2) {
    const oldest = owners.shift();
    if (!oldest) {
      break;
    }
    next[oldest.col1Id] = (next[oldest.col1Id] || []).filter((id) => id !== col2Item.id);
    if ((next[oldest.col1Id] || []).length === 0) {
      delete next[oldest.col1Id];
    }
  }

  return next;
};

export const removeItemFromMatches = (
  matches: MatchingMatches,
  itemId: string,
): MatchingMatches => {
  const next = cloneMatches(matches);
  delete next[itemId];
  Object.keys(next).forEach((c1Id) => {
    next[c1Id] = (next[c1Id] || []).filter((id) => id !== itemId);
    if (next[c1Id].length === 0) {
      delete next[c1Id];
    }
  });
  return next;
};

export const areMatchesEqual = (a: MatchingMatches, b: MatchingMatches): boolean => {
  const keysA = Object.keys(a || {}).sort();
  const keysB = Object.keys(b || {}).sort();
  if (keysA.length !== keysB.length) {
    return false;
  }
  return keysA.every((key) => {
    const left = [...(a[key] || [])].sort();
    const right = [...(b[key] || [])].sort();
    if (left.length !== right.length) {
      return false;
    }
    return left.every((id, i) => id === right[i]);
  });
};

export const computeCorrect = (model: MatchingModel, current: MatchingMatches): boolean => {
  const correct = model.correctMatches || {};
  if (countMatches(correct) === 0) {
    return false;
  }
  return areMatchesEqual(correct, current);
};

export const isLinkCorrect = (
  model: MatchingModel,
  current: MatchingMatches,
  col1Id: string,
  col2Id: string,
): boolean => {
  const correctTargets = model.correctMatches?.[col1Id] || [];
  return correctTargets.includes(col2Id) && isPairMatched(current, col1Id, col2Id);
};

export const matchedLabelsForItem = (
  model: MatchingModel,
  matches: MatchingMatches,
  col1Item: MatchingItem,
  col1Index: number,
): string[] => {
  const targets = matches[col1Item.id] || [];
  return targets
    .map((col2Id) => {
      const idx = (model.column2Items || []).findIndex((i) => i.id === col2Id);
      if (idx === -1) {
        return null;
      }
      return itemLabel(model.column2Items[idx], idx);
    })
    .filter((label): label is string => !!label);
};

export const buildResponses = (
  model: MatchingModel,
  matches: MatchingMatches,
  flags: {
    enabled: boolean;
    userModified: boolean;
    showCorrect: boolean;
    showHints: boolean;
    randomize: boolean;
  },
) => {
  const responses: Array<{ key: string; type: CapiVariableTypes; value: any }> = [
    { key: 'enabled', type: CapiVariableTypes.BOOLEAN, value: flags.enabled },
    { key: 'userModified', type: CapiVariableTypes.BOOLEAN, value: flags.userModified },
    { key: 'correct', type: CapiVariableTypes.BOOLEAN, value: computeCorrect(model, matches) },
    { key: 'showCorrect', type: CapiVariableTypes.BOOLEAN, value: flags.showCorrect },
    { key: 'showHints', type: CapiVariableTypes.BOOLEAN, value: flags.showHints },
    { key: 'randomize', type: CapiVariableTypes.BOOLEAN, value: flags.randomize },
    { key: 'matchCount', type: CapiVariableTypes.NUMBER, value: countMatches(matches) },
  ];

  (model.column1Items || []).forEach((item, index) => {
    responses.push({
      key: `${itemLabel(item, index)}.Matches`,
      type: CapiVariableTypes.ARRAY,
      value: matchedLabelsForItem(model, matches, item, index),
    });
  });

  return responses;
};

/** Restore learner matches from CAPI snapshot using `{label}.Matches` arrays. */
export const restoreMatches = (
  model: MatchingModel,
  snapshot: Record<string, any>,
  partId: string,
): MatchingMatches => {
  const matches: MatchingMatches = {};
  const col2ByLabel = new Map<string, string>();
  (model.column2Items || []).forEach((item, index) => {
    col2ByLabel.set(itemLabel(item, index), item.id);
  });

  (model.column1Items || []).forEach((item, index) => {
    const key = `stage.${partId}.${itemLabel(item, index)}.Matches`;
    const value = snapshot[key];
    if (!Array.isArray(value)) {
      return;
    }
    const targets = value
      .map((label) => (typeof label === 'string' ? col2ByLabel.get(label) : undefined))
      .filter((id): id is string => !!id);
    if (targets.length > 0) {
      matches[item.id] = targets;
    }
  });

  return matches;
};

export const correctMatchesSnapshot = (model: MatchingModel): MatchingMatches =>
  cloneMatches(model.correctMatches || {});

export interface LineEndpoint {
  x: number;
  y: number;
}

export interface DrawnLine {
  key: string;
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  col1Id: string;
  col2Id: string;
}

export const areDrawnLinesEqual = (a: DrawnLine[], b: DrawnLine[]): boolean => {
  if (a === b) {
    return true;
  }
  if (a.length !== b.length) {
    return false;
  }
  return a.every((line, index) => {
    const other = b[index];
    return (
      line.key === other.key &&
      line.x1 === other.x1 &&
      line.y1 === other.y1 &&
      line.x2 === other.x2 &&
      line.y2 === other.y2
    );
  });
};

export const bezierPath = (x1: number, y1: number, x2: number, y2: number): string => {
  const dx = Math.abs(x2 - x1) * 0.5;
  return `M ${x1} ${y1} C ${x1 + dx} ${y1}, ${x2 - dx} ${y2}, ${x2} ${y2}`;
};

export const buildDrawnLines = (
  matches: MatchingMatches,
  getEndpoint: (itemId: string, side: 'left' | 'right') => LineEndpoint | null,
): DrawnLine[] => {
  const lines: DrawnLine[] = [];
  Object.keys(matches || {}).forEach((col1Id) => {
    (matches[col1Id] || []).forEach((col2Id) => {
      const left = getEndpoint(col1Id, 'left');
      const right = getEndpoint(col2Id, 'right');
      if (!left || !right) {
        return;
      }
      lines.push({
        key: `${col1Id}__${col2Id}`,
        x1: left.x,
        y1: left.y,
        x2: right.x,
        y2: right.y,
        col1Id,
        col2Id,
      });
    });
  });
  return lines;
};
