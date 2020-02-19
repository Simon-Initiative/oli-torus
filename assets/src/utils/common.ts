/**
 * Returns the given value if it is not null or undefined. Otherwise, it returns
 * the default value. The return value will always be a defined value of the type given
 * @param value
 * @param defaultValue
 */
export const valueOr = <T>(value: T | null | undefined, defaultValue: T): T =>
  value === null || value === undefined ? defaultValue : value;

// Allows completeness checking in discriminated union based switch statements
export function assertNever(x: never): never {
  throw new Error('Unexpected object: ' + x);
}
