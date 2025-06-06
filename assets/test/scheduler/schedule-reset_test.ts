import { DateWithoutTime } from 'epoq';
import {
  countWorkingDays,
  findNthDay,
  findStartEnd,
  findStartEndByPercent,
  getPageCount,
  getTotalPageCount,
} from '../../src/apps/scheduler/schedule-reset';
import { HierarchyItem, ScheduleItemType } from '../../src/apps/scheduler/scheduler-slice';

const allDays = [true, true, true, true, true, true, true];
const weekdays = [false, true, true, true, true, true, false];

const hierarchItemTemplate: HierarchyItem = {
  startDate: null,
  endDate: null,
  endDateTime: null,
  startDateTime: null,
  children: [],
  end_date: '',
  start_date: '',
  id: 0,
  resource_id: 0,
  resource_type_id: ScheduleItemType.Container,
  scheduling_type: 'read_by',
  title: '',
  numbering_index: 0,
  numbering_level: 0,
  manually_scheduled: false,
  graded: false,
  removed_from_schedule: false,
};

describe('schedule-reset', () => {
  describe('findNthDay', () => {
    it('should return the first day', () => {
      expect(findNthDay(100, 1, allDays).getDaysSinceEpoch()).toEqual(100);
    });

    it('should return the first working day', () => {
      // The 100th day is 1970-04-11, which is a Saturday. So the first working day is 2 days later.
      expect(findNthDay(100, 1, weekdays).getDaysSinceEpoch()).toEqual(102);
    });

    it('should return next Monday', () => {
      // The 100th day is 1970-04-11, which is a Saturday. So the first working day is 2 days later, a monday, and 5 working days later is a monday again.
      expect(findNthDay(100, 6, weekdays).getDaysSinceEpoch()).toEqual(109);
      expect(findNthDay(100, 6, weekdays).getDay()).toEqual(1);
    });
  });

  describe('countWorkingDays', () => {
    it('should count all days', () => {
      expect(countWorkingDays(new DateWithoutTime(100), new DateWithoutTime(200), allDays)).toEqual(
        101,
      );
    });
    it('should count all week days', () => {
      expect(
        countWorkingDays(new DateWithoutTime(100), new DateWithoutTime(107), weekdays),
      ).toEqual(5);

      expect(
        countWorkingDays(new DateWithoutTime(100), new DateWithoutTime(200), weekdays),
      ).toEqual(71);
    });
  });

  describe('findStartEnd', () => {
    it('should find the start and end of a single day', () => {
      expect(findStartEnd(100, 1, allDays).map((d) => d.getDaysSinceEpoch())).toEqual([100, 100]);
      expect(findStartEnd(100, 1, weekdays).map((d) => d.getDaysSinceEpoch())).toEqual([102, 102]);
    });

    it('should find the start and end of a full 5 day week', () => {
      expect(findStartEnd(100, 5, allDays).map((d) => d.getDaysSinceEpoch())).toEqual([100, 104]);
      expect(findStartEnd(100, 5, weekdays).map((d) => d.getDaysSinceEpoch())).toEqual([102, 106]);
    });

    it('should find the start and end of two full 5 day weeks', () => {
      expect(findStartEnd(100, 10, allDays).map((d) => d.getDaysSinceEpoch())).toEqual([100, 109]);
      expect(findStartEnd(100, 10, weekdays).map((d) => d.getDaysSinceEpoch())).toEqual([102, 113]);
    });
  });

  describe('findStartEndByPercent', () => {
    // Params:
    // start: DateWithoutTime,
    // workingDayCount: number,
    // entryIndex: number,
    // totalEntries: number,
    // workingDays: boolean[]

    const toEpoq = (d: DateWithoutTime) => d.getDaysSinceEpoch();

    it("should find the first day's start and end", () => {
      expect(
        findStartEndByPercent(
          new DateWithoutTime(10),
          new DateWithoutTime(15),
          10,
          0,
          5,
          allDays,
          1,
          3,
        ).map(toEpoq),
      ).toEqual([10, 12]);

      expect(
        findStartEndByPercent(
          new DateWithoutTime(10),
          new DateWithoutTime(15),
          10,
          0,
          4,
          allDays,
          1,
          3,
        ).map(toEpoq),
      ).toEqual([10, 12]);

      expect(
        findStartEndByPercent(
          new DateWithoutTime(10),
          new DateWithoutTime(15),
          10,
          0,
          3,
          allDays,
          1,
          3,
        ).map(toEpoq),
      ).toEqual([10, 12]);
    });

    it("should find the second day's start and end", () => {
      expect(
        findStartEndByPercent(
          new DateWithoutTime(10),
          new DateWithoutTime(15),
          10,
          1,
          5,
          allDays,
          1,
          3,
        ).map(toEpoq),
      ).toEqual([10, 12]);

      expect(
        findStartEndByPercent(
          new DateWithoutTime(13),
          new DateWithoutTime(15),
          10,
          1,
          4,
          allDays,
          1,
          3,
        ).map(toEpoq),
      ).toEqual([13, 15]);

      expect(
        findStartEndByPercent(
          new DateWithoutTime(14),
          new DateWithoutTime(15),
          10,
          1,
          3,
          allDays,
          1,
          3,
        ).map(toEpoq),
      ).toEqual([14, 16]);
    });
  });

  describe('getPageCount', () => {
    it('returns 0 when item is undefined', () => {
      expect(getPageCount(undefined, [])).toBe(0);
    });

    it('returns 1 when item is a page', () => {
      const item: HierarchyItem = {
        ...hierarchItemTemplate,
        resource_type_id: ScheduleItemType.Page,
        children: [],
      };
      expect(getPageCount(item, [])).toBe(1);
    });

    it('returns 1 when item has no children', () => {
      const item: HierarchyItem = {
        ...hierarchItemTemplate,
        resource_type_id: ScheduleItemType.Container,
        children: [],
      };
      expect(getPageCount(item, [])).toBe(1);
    });

    it("returns sum of children's page count", () => {
      const item1: HierarchyItem = {
        ...hierarchItemTemplate,
        resource_type_id: ScheduleItemType.Container,
        children: [2, 3],
        id: 1,
      };
      const item2: HierarchyItem = {
        ...hierarchItemTemplate,
        resource_type_id: ScheduleItemType.Page,
        children: [],
        id: 2,
      };
      const item3: HierarchyItem = {
        ...hierarchItemTemplate,
        resource_type_id: ScheduleItemType.Container,
        children: [4],
        id: 3,
      };
      const item4: HierarchyItem = {
        ...hierarchItemTemplate,
        resource_type_id: ScheduleItemType.Page,
        children: [],
        id: 4,
      };
      const schedule: HierarchyItem[] = [item1, item2, item3, item4];

      expect(getPageCount(item1, schedule)).toBe(2);
      expect(getPageCount(item3, schedule)).toBe(1);
    });

    it('returns 1 for empty units', () => {
      const item: HierarchyItem = {
        ...hierarchItemTemplate,
        resource_type_id: ScheduleItemType.Container,
        children: [],
      };
      expect(getPageCount(item, [])).toBe(1);
    });
  });

  describe('getTotalPageCount', () => {
    it('should return 0 when given an empty array', () => {
      const schedule: HierarchyItem[] = [];
      const result = getTotalPageCount(schedule);
      expect(result).toBe(0);
    });

    it('should return the number of pages in the schedule', () => {
      const schedule: HierarchyItem[] = [
        {
          ...hierarchItemTemplate,
          id: 1,
          resource_id: 1,
          resource_type_id: ScheduleItemType.Page,
        },
        {
          ...hierarchItemTemplate,
          id: 2,
          resource_id: 2,
          resource_type_id: ScheduleItemType.Container,
        },
        {
          ...hierarchItemTemplate,
          id: 3,
          resource_type_id: ScheduleItemType.Page,
          scheduling_type: 'due_by',
        },
      ];
      const result = getTotalPageCount(schedule);
      expect(result).toBe(3);
    });

    it('should count containers with no children as pages', () => {
      const schedule: HierarchyItem[] = [
        {
          ...hierarchItemTemplate,

          id: 1,
          resource_id: 1,
          resource_type_id: ScheduleItemType.Container,
        },
        {
          ...hierarchItemTemplate,
          children: [2],

          id: 3,
          resource_id: 3,
          resource_type_id: ScheduleItemType.Container,
        },
        {
          ...hierarchItemTemplate,

          children: [],
          end_date: '',
          start_date: '',
          id: 2,
          resource_id: 2,
          resource_type_id: ScheduleItemType.Page,
          scheduling_type: 'due_by',
          title: '',
          numbering_index: 0,
          numbering_level: 0,
          manually_scheduled: false,
          removed_from_schedule: false,
          graded: false,
        },
      ];
      const result = getTotalPageCount(schedule);
      expect(result).toBe(2);
    });
  });
});
