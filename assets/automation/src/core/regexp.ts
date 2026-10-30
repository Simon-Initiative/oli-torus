/** Escapes `value` so a `RegExp` built from it matches the text literally. */
export function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
