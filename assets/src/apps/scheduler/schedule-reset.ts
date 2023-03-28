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
  if (start.getDaysSinceEpoch() > end.getDaysSinceEpoch()) {
    console.log('ERROR: start > end', start, end);
  }
  return [start, end];
};

/*
  Using just findStartEnd has a problem where it will exceed the end-date if we have more children than
  working days to schedule since each child is scheduled for at least 1 day. This function
  will try to spread out the starting days evenly within the range of start and end.
*/
export const findStartEndByPercent = (
  start: DateWithoutTime,
  workingDayCount: number,
  entryIndex: number,
  totalEntries: number,
  weekdaysToSchedule: boolean[],
) => {
  const length = Math.ceil(workingDayCount / totalEntries);
  const startingDayIndex = (workingDayCount * entryIndex) / totalEntries + 1;

  const calculatedStart = findNthDay(
    start.getDaysSinceEpoch(),
    startingDayIndex,
    weekdaysToSchedule,
  );
  const calculatedEnd = findNthDay(calculatedStart.getDaysSinceEpoch(), length, weekdaysToSchedule);

  return [calculatedStart, calculatedEnd];
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

  const dayCount = countWorkingDays(start, end, weekdaysToSchedule);

  for (const [index, childId] of target.children.entries()) {
    const child = getScheduleItem(childId, schedule);

    // start: DateWithoutTime,
    // workingDayCount: number,
    // entryIndex: number,
    // totalEntries: number,
    // workingDays: boolean[]

    // const [calculatedStart, calculatedEnd] = findStartEnd(startDay, length, weekdaysToSchedule);
    const [calculatedStart, calculatedEnd] = findStartEndByPercent(
      start,
      dayCount,
      index,
      target.children.length,
      weekdaysToSchedule,
    );

    if (child && (resetManual || !child?.manually_scheduled)) {
      child.startDate =
        child.resource_type_id === ScheduleItemType.Container ? calculatedStart : null;
      child.endDate = calculatedEnd;

      const delta = child.endDate.getDaysSinceEpoch() - end.getDaysSinceEpoch();
      if (delta > 0) {
        child.endDate.addDays(-delta);
      }
      if (
        child.startDate &&
        child.endDate.getDaysSinceEpoch() < child.startDate.getDaysSinceEpoch()
      ) {
        child.startDate = new DateWithoutTime(end.getDaysSinceEpoch());
      }

      child.endDateTime = new Date(
        child.endDate.getFullYear(),
        child.endDate.getMonth(),
        child.endDate.getDate(),
        23,
        59,
        59,
        999,
      );

      resetScheduleItem(child, calculatedStart, child.endDate, schedule);
    }
  }
};
