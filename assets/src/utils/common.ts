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

// Matches server implementation in `lib/oli/activities/parse_utils.ex`
export function removeEmpty(items: any[]) {
  return items.filter(hasContent);
}
// Forgive me for I have sinned
function hasContent(item: any) {
  try {
    if (item.content) {
      const content = item.content;
      if (content.model) {
        const model = content.model;
        if (model && model.length === 1) {
          const children = model[0].children;
          const type = model[0].type;
          if (type === 'p' && children && children.length === 1) {
            const text = children[0].text;
            if (!text || !text.trim || !text.trim()) {
              return false;
            }
          }
        }
      }
    }
    return true;
  } catch (e) {
    return true;
  }
}
