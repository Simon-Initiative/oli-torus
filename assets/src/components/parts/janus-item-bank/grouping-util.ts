import { CSSProperties } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  DEFAULT_GROUPING_MIN_HEIGHT,
  GroupingCategory,
  GroupingItem,
  GroupingModel,
  RESPONSIVE_GROUPING_MIN_HEIGHT,
} from './schema';

// Zone id used to represent the item bank (distinct from any category id).
export const BANK_ID = 'bank';
export const BANK_LABEL = 'Item Bank';

export { DEFAULT_GROUPING_MIN_HEIGHT, RESPONSIVE_GROUPING_MIN_HEIGHT };

export const isResponsiveGroupingLayout = (width?: number | string): boolean =>
  width === '100%' || (typeof width === 'string' && width.includes('%'));

export const groupingLayoutClass = (width?: number | string): string =>
  isResponsiveGroupingLayout(width) ? 'grouping--responsive' : 'grouping--fixed';

export const groupingMinHeight = (width?: number | string, height?: number): number => {
  if (isResponsiveGroupingLayout(width)) {
    return Math.max(RESPONSIVE_GROUPING_MIN_HEIGHT, height ?? RESPONSIVE_GROUPING_MIN_HEIGHT);
  }
  return height ?? DEFAULT_GROUPING_MIN_HEIGHT;
};

export const DEFAULT_GROUPING_THEME = '#2e9fff';

export const groupingThemeStyles = (themeColor?: string): CSSProperties => ({
  ['--grouping-theme' as string]: themeColor || DEFAULT_GROUPING_THEME,
});

export const groupingContainerStyles = (
  width?: number | string,
  height?: number,
): CSSProperties => {
  const minHeight = groupingMinHeight(width, height);
  const cssVar = { ['--grouping-min-height' as string]: `${minHeight}px` };

  if (isResponsiveGroupingLayout(width)) {
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

// Placement maps an item id to the zone it currently sits in.
// A missing entry (or BANK_ID) means the item is still in the item bank.
export type Placements = Record<string, string>;

export const isInBank = (placements: Placements, itemId: string): boolean => {
  const zone = placements[itemId];
  return !zone || zone === BANK_ID;
};

export const itemDisplayText = (item: GroupingItem): string =>
  (item.text && item.text.trim().length > 0 ? item.text : item.label) || '';

export const itemImageCaption = (item: GroupingItem): string => {
  if (item.type !== 'image' || item.text == null) {
    return '';
  }
  return item.text.trim();
};

/** Ensure image items always carry an explicit `text` value for redux lodash merge saves. */
export const normalizeGroupingItemForSave = (item: GroupingItem): GroupingItem => {
  if (item.type !== 'image') {
    return item;
  }
  return {
    ...item,
    text: (item.text || '').trim(),
  };
};

export const normalizeGroupingItemsForSave = (items: GroupingItem[]): GroupingItem[] =>
  items.map(normalizeGroupingItemForSave);

export const categoryTitle = (category: GroupingCategory, index: number): string =>
  (category?.title || '').trim() || `Category ${index + 1}`;

export const itemLabel = (item: GroupingItem, index: number): string =>
  (item?.label || '').trim() || `Item ${index + 1}`;

export const locationLabelForZone = (model: GroupingModel, zoneId: string): string => {
  if (!zoneId || zoneId === BANK_ID) {
    return BANK_LABEL;
  }
  const idx = (model.categories || []).findIndex((c) => c.id === zoneId);
  if (idx === -1) {
    return BANK_LABEL;
  }
  return categoryTitle(model.categories[idx], idx);
};

export const itemsInZone = (
  model: GroupingModel,
  placements: Placements,
  zoneId: string,
): GroupingItem[] =>
  (model.items || []).filter((item) =>
    zoneId === BANK_ID ? isInBank(placements, item.id) : placements[item.id] === zoneId,
  );

export const countItemsInZone = (
  model: GroupingModel,
  placements: Placements,
  zoneId: string,
): number => itemsInZone(model, placements, zoneId).length;

// An item is correctly placed when its current zone matches the authored
// correct category for that item.
export const isItemCorrect = (
  model: GroupingModel,
  placements: Placements,
  itemId: string,
): boolean => {
  const correctZone = (model.correctAnswer || {})[itemId];
  if (!correctZone) {
    // No correct answer authored for this item: it is only "correct" when in the bank.
    return isInBank(placements, itemId);
  }
  return placements[itemId] === correctZone;
};

// The whole component is correct when every item is in its authored correct
// category (and there is at least one authored correct placement).
export const computeCorrect = (model: GroupingModel, placements: Placements): boolean => {
  const correctAnswer = model.correctAnswer || {};
  const authoredCount = Object.keys(correctAnswer).length;
  if (authoredCount === 0) {
    return false;
  }
  return (model.items || []).every((item) => isItemCorrect(model, placements, item.id));
};

// Builds the set of CAPI responses describing the current state of the
// component. Used by both onInit and onSave so the keys stay consistent.
export const buildResponses = (
  model: GroupingModel,
  placements: Placements,
  flags: {
    enabled: boolean;
    userModified: boolean;
    showCorrect: boolean;
    showHints: boolean;
  },
) => {
  const responses: Array<{ key: string; type: CapiVariableTypes; value: any }> = [
    { key: 'enabled', type: CapiVariableTypes.BOOLEAN, value: flags.enabled },
    { key: 'userModified', type: CapiVariableTypes.BOOLEAN, value: flags.userModified },
    { key: 'correct', type: CapiVariableTypes.BOOLEAN, value: computeCorrect(model, placements) },
    { key: 'showCorrect', type: CapiVariableTypes.BOOLEAN, value: flags.showCorrect },
    { key: 'showHints', type: CapiVariableTypes.BOOLEAN, value: flags.showHints },
    {
      key: 'itemBankCount',
      type: CapiVariableTypes.NUMBER,
      value: countItemsInZone(model, placements, BANK_ID),
    },
  ];

  (model.categories || []).forEach((category, index) => {
    responses.push({
      key: `${categoryTitle(category, index)}.Count`,
      type: CapiVariableTypes.NUMBER,
      value: countItemsInZone(model, placements, category.id),
    });
  });

  (model.items || []).forEach((item, index) => {
    responses.push({
      key: `${itemLabel(item, index)}.Location`,
      type: CapiVariableTypes.STRING,
      value: locationLabelForZone(model, placements[item.id] || BANK_ID),
    });
  });

  return responses;
};

// Reconstructs placements from a CAPI snapshot by matching each item's
// "<label>.Location" string back to a category by title. Used on init and on
// context change to restore learner progress.
export const restorePlacements = (
  model: GroupingModel,
  snapshot: Record<string, any>,
  partId: string,
): Placements => {
  const placements: Placements = {};
  (model.items || []).forEach((item, index) => {
    const key = `stage.${partId}.${itemLabel(item, index)}.Location`;
    const location = snapshot[key];
    if (typeof location === 'string' && location && location !== BANK_LABEL) {
      const idx = (model.categories || []).findIndex((c, i) => categoryTitle(c, i) === location);
      if (idx !== -1) {
        placements[item.id] = model.categories[idx].id;
      }
    }
  });
  return placements;
};

// Places every item into its authored correct category (used by Show Answer).
export const correctPlacements = (model: GroupingModel): Placements => {
  const placements: Placements = {};
  (model.items || []).forEach((item) => {
    const correctZone = (model.correctAnswer || {})[item.id];
    if (correctZone) {
      placements[item.id] = correctZone;
    }
  });
  return placements;
};
