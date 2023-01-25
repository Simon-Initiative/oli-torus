import { DateWithoutTime } from 'epoq';
import { HierarchyItem } from './scheduler-slice';

export const resetScheduleItem = (
  root: HierarchyItem,
  start: DateWithoutTime,
  end: DateWithoutTime,
) => {
  const count = root.children.length;
  if (count === 0) return;
  // Day based calculations...
  let startDay = start.getDaysSinceEpoch();
  const endDay = end.getDaysSinceEpoch();
  const dayCount = endDay - startDay;
  const itemSpacing = dayCount / count;
  const itemLength = Math.ceil(dayCount / count);
  for (const child of root.children) {
    child.start_date = new DateWithoutTime(Math.floor(startDay));
    child.end_date = new DateWithoutTime(
      Math.min(Math.floor(startDay + itemLength), end.getDaysSinceEpoch()),
    );
    startDay += itemSpacing;
    resetScheduleItem(child, child.start_date, child.end_date);
  }
};
