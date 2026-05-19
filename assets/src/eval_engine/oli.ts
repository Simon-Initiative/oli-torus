/**
 * Returns true if two numbers are "almost equal" within a given difference.
 * @param a - The first number to compare
 * @param b - The second number to compare
 * @param difference - The numerical difference allowed to be considered "almost equal".
 * If ommited, 10 ** -7 is used.
 */
export const almostEqual = (a: number, b: number, difference: number = 10 ** -7) => {
  return Math.abs(a - b) < difference;
};

/**
 * Returns The greatest common divisor of two dividends.
 * @param x - The first dividend
 * @param y  - The second dividend
 */
export const gcd = (x: number, y: number) => {
  let absX = Math.abs(x);
  let absY = Math.abs(y);
  while (absY) {
    const t = absY;
    absY = absX % absY;
    absX = t;
  }
  return absX;
};

/**
 * Returns the value of a number in radians.
 * @param d - The value in degrees
 */
export const toRadians = (d: number) => {
  return d * (Math.PI / 180);
};

/**
 * Returns the rounded value of a number.
 * @param num - The number to round
 * @param decimalPositions - The number of decimal positions to round to
 */
export const round = (num: number, decimalPositions = 1) => {
  const m = Math.pow(10, decimalPositions);
  return Math.round(num * m) / m;
};

/**
 * Returns a randomly selected value from an array.
 * @param arr - The array to select from
 */
export const randomArrayItem = (arr: any[]) => {
  return arr[random(0, arr.length)];
};

/**
 * Returns a randomly generated integer with a range.
 * @param lower - The lower bound
 * @param upper - The upper bound
 */
export const randomInt = (lower: number, upper: number) => {
  return Math.floor(Math.random() * (upper - lower) + lower);
};

/**
 * Returns a randomly generated number within a range, with the specified
 * decimal positions.
 * @param lower - The lower bound
 * @param upper - The upper bound
 * @param decimalPositions - Number of decimal positions. If ommited, zero is used.
 */
export const random = (lower: number, upper: number, decimalPositions = 0) => {
  if (lower === undefined) {
    return Math.random();
  }
  if (decimalPositions === 0) {
    // Return random integer value beween lower and upper, exluding upper,
    // but including lower
    return Math.floor(Math.random() * (upper - lower)) + lower;
  }

  const value = Math.random() * (upper - lower) + lower;
  const result = '' + value;
  const dot = result.lastIndexOf('.');

  if (dot === -1) {
    return Number(result);
  }

  return Number(result.substr(0, dot + (decimalPositions + 1)));
};
