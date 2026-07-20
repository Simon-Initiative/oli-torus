import { ListSortItem } from './schema';

export const orderById = (items: ListSortItem[], ids: string[]): ListSortItem[] => {
  const byId = new Map(items.map((item) => [item.id, item]));
  const ordered = ids.map((id) => byId.get(id)).filter((item): item is ListSortItem => !!item);
  const missing = items.filter((item) => !ids.includes(item.id));
  return [...ordered, ...missing];
};

export const correctOrderItems = (items: ListSortItem[], correctIds: string[]): ListSortItem[] =>
  orderById(items, correctIds);

export const barColorForItem = (baseColor: string, index: number, total: number): string => {
  if (total <= 1) {
    return baseColor;
  }
  const ratio = index / (total - 1);
  const mixPercent = Math.round(100 - ratio * 65);
  return `color-mix(in srgb, ${baseColor} ${mixPercent}%, white)`;
};

export const itemBarStyle = (
  baseColor: string,
  index: number,
  total: number,
): Record<string, string> => ({
  '--list-sort-item-bar-color': barColorForItem(baseColor, index, total),
});

export const isItemInCorrectPosition = (
  itemId: string,
  index: number,
  correctIds: string[],
): boolean => correctIds[index] === itemId;
