import { DateWithoutTime } from 'epoq';
import { getScheduleItem, HierarchyItem, ScheduleItemType } from './scheduler-slice';

export const countWorkingDays = (
  start: DateWithoutTime,
  end: DateWithoutTime,
  weekdaysToSchedule: boolean[], // First entry is Sunday, last is Saturday
) => {
  // TODO - eventually, we can add in more complex logic here to account for holidays, etc.
  let days = 0;
  const current = new DateWithoutTime(start.getDaysSinceEpoch());
  while (current.getDaysSinceEpoch() <= end.getDaysSinceEpoch()) {
    if (weekdaysToSchedule[current.getDay()]) days++;
    current.addDays(1);
  }
  return days;
};

export const findNthDay = (startDay: number, n: number, weekdaysToSchedule: boolean[]) => {
  const start = new DateWithoutTime(Math.floor(startDay) - 1);
  let workdays = 0;
  while (workdays < n) {
    start.addDays(1);
    if (weekdaysToSchedule[start.getDay()]) {
      workdays++;
    }
  }
  return start;
};

export const findStartEnd = (startDay: number, days: number, weekdaysToSchedule: boolean[]) => {
  const start = findNthDay(startDay, 1, weekdaysToSchedule);
  const end = findNthDay(start.getDaysSinceEpoch(), days, weekdaysToSchedule);
  return [start, end];
};

export const resetScheduleItem = (
  target: HierarchyItem,
  start: DateWithoutTime,
  end: DateWithoutTime,
  schedule: HierarchyItem[],
  resetManual = true,
  weekdaysToSchedule = [false, true, true, true, true, true, false],
) => {
  const count = target.children.map((id) => getScheduleItem(id, schedule)).length;

  if (resetManual) target.manually_scheduled = false;
  if (count === 0) return;
  let startDay = start.getDaysSinceEpoch();
  const dayCount = countWorkingDays(start, end, weekdaysToSchedule);

  const itemLength = dayCount / count;
  let leftover = 0;

  for (const childId of target.children) {
    const child = getScheduleItem(childId, schedule);

    // We want to round to full days, but we also want to distribute the leftover days evenly across the items.
    let length = Math.floor(itemLength);
    leftover += itemLength % 1;
    if (leftover >= 1) {
      leftover -= 1;
      length += 1;
    }

    const [start, end] = findStartEnd(startDay, length, weekdaysToSchedule);

    if (child && (resetManual || !child?.manually_scheduled)) {
      child.startDate = child.resource_type_id === ScheduleItemType.Container ? start : null;
      child.endDate = end;
      resetScheduleItem(child, start, child.endDate, schedule);
    }
    startDay = end.getDaysSinceEpoch() + 1;
  }
};
