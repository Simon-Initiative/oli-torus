import * as Oli from 'eval_engine/oli';

describe('Oli Module', () => {
  describe('almostEqual', () => {
    test('should return true for numbers within difference allowance', () => {
      expect(Oli.almostEqual(4.123, 4.126, 10 ** -2)).toBe(true);
    });

    test('should return false for numbers outside difference allowance', () => {
      expect(Oli.almostEqual(4.123, 4.126, 10 ** -3)).toBe(false);
    });
  });

  describe('gcd', () => {
    test('should calculate greatest common divisor of 220 and 8', () => {
      expect(Oli.gcd(220, 8)).toBe(4);
    });
  });

  describe('toRadians', () => {
    test('should convert 120 deg to 2.0944 rads (to 5 significant figures)', () => {
      expect(Oli.toRadians(120).toPrecision(5)).toBe('2.0944');
    });
  });

  describe('round', () => {
    test('should round Math.PI to 5 decimal places', () => {
      expect(Oli.round(Math.PI, 5)).toEqual(3.14159);
    });

    test('should round Math.PI to default 1 decimal places', () => {
      expect(Oli.round(Math.PI)).toEqual(3.1);
    });
  });

  describe('randomArrayItem', () => {
    test('should return a random item from the array [1, 3, 5, 9]', () => {
      const testArray = [1, 3, 5, 9];
      const randomItem = Oli.randomArrayItem([1, 3, 5, 9]);
      expect(testArray.includes(randomItem)).toBe(true);
    });

    test('should return undefined for empty array', () => {
      expect(Oli.randomArrayItem([])).toBe(undefined);
    });
  });

  describe('randomInt', () => {
    test('should return a random integer within the specified range - run 20x', () => {
      Array.from({ length: 20 }).forEach(() => {
        const randomInt = Oli.randomInt(45, 47);
        expect(Number.isInteger(randomInt)).toBe(true);
        expect(randomInt >= 45 && randomInt <= 47).toBe(true);
      });
    });
  });

  describe('random', () => {
    test('should return a random number within the specified range - run 20x', () => {
      Array.from({ length: 20 }).forEach(() => {
        const random = Oli.random(45, 47);
        expect(Number.isInteger(random)).toBe(true);
        expect(random >= 45 && random <= 47).toEqual(true);
      });
    });
  });
});
