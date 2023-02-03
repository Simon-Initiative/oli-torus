import { DateWithoutTime } from 'epoq';
import { getScheduleItem, HierarchyItem } from './scheduler-slice';

export const resetScheduleItem = (
  target: HierarchyItem,
  start: DateWithoutTime,
  end: DateWithoutTime,
  schedule: HierarchyItem[],
  resetManual = true,
) => {
  const count = target.children
    .map((id) => getScheduleItem(id, schedule))
    .filter((item) => resetManual || !item?.manually_scheduled).length;

  if (resetManual) target.manually_scheduled = false;
  if (count === 0) return;
  // Day based calculations...
  let startDay = start.getDaysSinceEpoch();
  const endDay = end.getDaysSinceEpoch();
  const dayCount = endDay - startDay;
  const itemSpacing = dayCount / count;
  const itemLength = Math.ceil(dayCount / count);

  for (const childId of target.children) {
    const child = getScheduleItem(childId, schedule);
    if (child && (resetManual || !child?.manually_scheduled)) {
      child.startDate = new DateWithoutTime(Math.floor(startDay));
      child.endDate = new DateWithoutTime(
        Math.min(Math.floor(startDay + itemLength), end.getDaysSinceEpoch()),
      );
      startDay += itemSpacing;
      resetScheduleItem(child, child.startDate, child.endDate, schedule);
    }
  }
};
