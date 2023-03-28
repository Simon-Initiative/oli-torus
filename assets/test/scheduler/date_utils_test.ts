import { DateWithoutTime } from 'epoq';
import { barGeometry, generateDayGeometry, leftToDate } from '../../src/apps/scheduler/date-utils';

describe('Scheduler date utils', () => {
  describe('generateGeometry', () => {
    it('Should generate geometries from a date range', () => {
      const startDate = new DateWithoutTime(10);
      const endDate = new DateWithoutTime(14);
      expect(generateDayGeometry(startDate, endDate, 100)).toEqual({
        start: startDate,
        end: endDate,
        availableWidth: 100,
        geometry: [
          { left: 0, width: 20, date: new DateWithoutTime(10) },
          { left: 20, width: 20, date: new DateWithoutTime(11) },
          { left: 40, width: 20, date: new DateWithoutTime(12) },
          { left: 60, width: 20, date: new DateWithoutTime(13) },
          { left: 80, width: 20, date: new DateWithoutTime(14) },
        ],
      });

      expect(generateDayGeometry(startDate, endDate, 101)).toEqual({
        start: startDate,
        end: endDate,
        availableWidth: 101,
        geometry: [
          { left: 0, width: 20, date: new DateWithoutTime(10) },
          { left: 20, width: 20, date: new DateWithoutTime(11) },
          { left: 40, width: 20, date: new DateWithoutTime(12) },
          { left: 60, width: 20, date: new DateWithoutTime(13) },
          { left: 80, width: 21, date: new DateWithoutTime(14) },
        ],
      });

      expect(generateDayGeometry(startDate, endDate, 102)).toEqual({
        start: startDate,
        end: endDate,
        availableWidth: 102,
        geometry: [
          { left: 0, width: 20, date: new DateWithoutTime(10) },
          { left: 20, width: 20, date: new DateWithoutTime(11) },
          { left: 40, width: 21, date: new DateWithoutTime(12) },
          { left: 61, width: 20, date: new DateWithoutTime(13) },
          { left: 81, width: 21, date: new DateWithoutTime(14) },
        ],
      });
    });
  });

  describe('barGeometry', () => {
    const startDate = new DateWithoutTime(10);
    const endDate = new DateWithoutTime(14);
    const geometry = generateDayGeometry(startDate, endDate, 100);

    it('Should generate bar geometry under normal circumstances', () => {
      expect(barGeometry(geometry, startDate, endDate)).toEqual({ left: 0, width: 100 });
      expect(barGeometry(geometry, startDate, startDate)).toEqual({ left: 0, width: 20 });
      expect(barGeometry(geometry, startDate, new DateWithoutTime(11))).toEqual({
        left: 0,
        width: 40,
      });

      expect(barGeometry(geometry, new DateWithoutTime(11), new DateWithoutTime(11))).toEqual({
        left: 20,
        width: 20,
      });
    });

    it('Should generate geometry if dates are out of order', () => {
      expect(barGeometry(geometry, new DateWithoutTime(12), new DateWithoutTime(11))).toEqual({
        left: 20,
        width: 40,
      });
    });

    it('Should generate geometry if there is no end date', () => {
      expect(barGeometry(geometry, new DateWithoutTime(12), null)).toEqual({
        left: 40,
        width: 20,
      });
    });

    it('Should have a default', () => {
      expect(barGeometry(geometry, null, null)).toEqual({
        left: 0,
        width: 0,
      });
    });

    it('Should work if our end-date is past our range', () => {
      expect(barGeometry(geometry, startDate, new DateWithoutTime(100))).toEqual({
        left: 0,
        width: 100,
      });
    });

    it('Should work if our start-date is past our range', () => {
      expect(barGeometry(geometry, new DateWithoutTime(0), new DateWithoutTime(100))).toEqual({
        left: 0,
        width: 100,
      });

      expect(barGeometry(geometry, new DateWithoutTime(0), new DateWithoutTime(12))).toEqual({
        left: 0,
        width: 60,
      });
    });
  });

  describe('leftToDate', () => {
    const startDate = new DateWithoutTime(10);
    const endDate = new DateWithoutTime(14);
    const geometry = generateDayGeometry(startDate, endDate, 100);

    it('Should return the date for a given left position', () => {
      let i;
      for (i = 0; i <= 19; i++) {
        expect(leftToDate(i, geometry)?.date).toEqual(startDate);
      }
      for (i = 20; i <= 39; i++) {
        expect(leftToDate(i, geometry)?.date).toEqual(new DateWithoutTime(11));
      }
      for (i = 40; i <= 59; i++) {
        expect(leftToDate(i, geometry)?.date).toEqual(new DateWithoutTime(12));
      }
      expect(leftToDate(60, geometry)?.date).toEqual(new DateWithoutTime(13));
      expect(leftToDate(80, geometry)?.date).toEqual(new DateWithoutTime(14));
    });

    it('Should return the start date if the left is before the start', () => {
      expect(leftToDate(-1, geometry)?.date).toEqual(startDate);
    });

    it('Should return the end date if the left is after the end', () => {
      expect(leftToDate(501, geometry)?.date).toEqual(endDate);
    });
  });
});
