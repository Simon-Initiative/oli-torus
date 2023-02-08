import {
  countWorkingDays,
  findNthDay,
  findStartEnd,
} from '../../src/apps/scheduler/schedule-reset';
import { DateWithoutTime } from 'epoq';

const allDays = [true, true, true, true, true, true, true];
const weekdays = [false, true, true, true, true, true, false];

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
});
