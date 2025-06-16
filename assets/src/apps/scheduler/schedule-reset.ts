import { DateWithoutTime } from 'epoq';
import {
  AssessmentLayoutType,
  HierarchyItem,
  ScheduleItemType,
  getScheduleItem,
} from './scheduler-slice';

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
  if (n === 0) return new DateWithoutTime(startDay);

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
  end: DateWithoutTime,
  workingDayCount: number,
  entryIndex: number,
  totalEntries: number,
  weekdaysToSchedule: boolean[],
  pageLength: number,
  totalPageLength: number,
) => {
  if (entryIndex === totalEntries - 1) {
    // Due to rounding, sometimes the last entry will be off by a day. This is a hack to fix that.
    return [start, end];
  }

  const percentOfWhole = pageLength / totalPageLength;

  const length = Math.ceil(workingDayCount * percentOfWhole);
  const calculatedEnd = findNthDay(start.getDaysSinceEpoch(), length - 1, weekdaysToSchedule);

  return [start, calculatedEnd];
};

export const getPageCount = (
  item: HierarchyItem | undefined,
  schedule: HierarchyItem[],
): number => {
  if (!item) return 0;
  if (item.resource_type_id === ScheduleItemType.Page) return item.removed_from_schedule ? 0 : 1;
  const childrenIds = item.children.filter((id) => {
    const child = getScheduleItem(id, schedule);
    return child && !child.removed_from_schedule;
  });
  if (childrenIds.length === 0) return 1; // Empty units still get to take up some space.
  return item.children.reduce(
    (acc, id) => acc + getPageCount(getScheduleItem(id, schedule), schedule),
    0,
  );
};

export const getTotalPageCount = (schedule: HierarchyItem[]): number =>
  schedule.filter((item) => {
    // We want a count of all pages, PLUS containers with no children (since they still need room)
    return item.resource_type_id === ScheduleItemType.Page || item.children.length === 0;
  }).length;

export const clearScheduleItem = (target: HierarchyItem, schedule: HierarchyItem[]) => {
  target.startDate = null;
  target.endDate = null;
  target.startDateTime = null;
  target.endDateTime = null;
  target.manually_scheduled = false;
  target.removed_from_schedule = false;
  const children = target.children.map((id) => getScheduleItem(id, schedule));
  children.filter((child) => !!child).forEach((child) => clearScheduleItem(child!, schedule));
};

export const resetScheduleItem = (
  target: HierarchyItem,
  start: DateWithoutTime,
  end: DateWithoutTime,
  schedule: HierarchyItem[],
  resetManual = true,
  weekdaysToSchedule = [false, true, true, true, true, true, false],
  preferredTime: {
    hour: number;
    minute: number;
    second: number;
  },
  assessmentLayoutType: AssessmentLayoutType,
) => {
  const hasChildren = !!target.children.map((id) => getScheduleItem(id, schedule)).length;

  if (resetManual) target.manually_scheduled = false;
  if (!hasChildren) return;

  const totalPages = getPageCount(target, schedule); //getTotalPageCount(schedule);
  if (totalPages === 0) return;
  const dayCount = countWorkingDays(start, end, weekdaysToSchedule);

  let nextStart = start;

  const childrenIds = target.children.filter((id) => {
    const child = getScheduleItem(id, schedule);
    return child && !child.removed_from_schedule;
  });

  for (const [index, childId] of childrenIds.entries()) {
    const child = getScheduleItem(childId, schedule);

    // start: DateWithoutTime,
    // workingDayCount: number,
    // entryIndex: number,
    // totalEntries: number,
    // workingDays: boolean[]

    // const [calculatedStart, calculatedEnd] = findStartEnd(startDay, length, weekdaysToSchedule);
    const [calculatedStart, calculatedEnd] = findStartEndByPercent(
      nextStart,
      end,
      dayCount,
      index,
      childrenIds.length,
      weekdaysToSchedule,
      getPageCount(child, schedule),
      totalPages,
    );

    nextStart = findNthDay(calculatedEnd.getDaysSinceEpoch(), 2, weekdaysToSchedule);

    if (child && (resetManual || !child?.manually_scheduled)) {
      child.startDate =
        child.resource_type_id === ScheduleItemType.Container ? calculatedStart : null;
      if (child.graded) {
        if (assessmentLayoutType === 'no_due_dates') {
          child.endDate = null;
        } else if (assessmentLayoutType === 'end_of_each_section') {
          schedule.forEach((potentialParent) => {
            if (potentialParent.children.includes(child.id)) {
              child.endDate = new DateWithoutTime(
                potentialParent.endDate?.getDaysSinceEpoch() || end.getDaysSinceEpoch(),
              );
            }
          });
        } else {
          child.endDate = calculatedEnd;
        }
      } else {
        child.endDate = calculatedEnd;
      }

      const delta =
        child.endDate !== null ? child.endDate.getDaysSinceEpoch() - end.getDaysSinceEpoch() : 0;
      if (child.endDate !== null && delta > 0) {
        // Make sure we never schedule past the end.
        child.endDate.addDays(-delta);
      }

      if (
        child.startDate &&
        child.endDate &&
        child.endDate.getDaysSinceEpoch() < child.startDate.getDaysSinceEpoch()
      ) {
        // Make sure the start date is never after the end date.
        child.startDate = new DateWithoutTime(end.getDaysSinceEpoch());
      }

      if (child.startDate) {
        child.startDateTime = new Date(
          child.startDate.getFullYear(),
          child.startDate.getMonth(),
          child.startDate.getDate(),
          preferredTime.hour,
          preferredTime.minute,
          preferredTime.second,
          0,
        );
      } else {
        child.startDateTime = null;
      }

      child.endDateTime = child.endDate
        ? new Date(
            child.endDate.getFullYear(),
            child.endDate.getMonth(),
            child.endDate.getDate(),
            preferredTime.hour,
            preferredTime.minute,
            preferredTime.second,
            0,
          )
        : null;

      resetScheduleItem(
        child,
        calculatedStart,
        calculatedEnd,
        schedule,
        resetManual,
        weekdaysToSchedule,
        preferredTime,
        assessmentLayoutType,
      );
    }
  }
};
