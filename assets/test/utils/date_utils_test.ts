import { DateWithoutTime } from 'epoq';
import { stringToDateWithoutTime } from 'apps/scheduler/date-utils';

describe('date_utils', () => {
  describe('DateWithoutTime', () => {
    it('Should work with january dates', () => {
      const d = new DateWithoutTime(2024, 0, 18);
      expect(d.getFullYear()).toEqual(2024);
    });
  });
  describe('stringToDateWithoutTime', () => {
    it('Should work with january dates', () => {
      const d = stringToDateWithoutTime('2024-01-18');
      expect(d.getFullYear()).toEqual(2024);
      expect(d.getMonth()).toEqual(0);
      expect(d.getDate()).toEqual(18);
    });
  });
});
