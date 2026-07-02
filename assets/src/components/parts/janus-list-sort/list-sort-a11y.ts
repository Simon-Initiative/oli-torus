export const LIST_SORT_INSTRUCTIONS =
  'Tab through items and use space bar or enter to select and deselect the item. Once an item is selected, tab through the list or use arrow keys to move the selected item.';

export const buildItemAccessibleName = (text: string): string => text;

export const buildFocusAnnouncement = (
  index: number,
  total: number,
  text: string,
  isSelected: boolean,
): string => {
  const position = `Position ${index + 1} of ${total}. ${text}.`;
  if (isSelected) {
    return `${position} Press space bar or enter to deselect. Use arrow keys to move.`;
  }
  return `${position} Press space bar or enter to select.`;
};

export const buildPositionAnnouncement = (index: number, total: number): string =>
  `Position ${index + 1} of ${total}.`;
