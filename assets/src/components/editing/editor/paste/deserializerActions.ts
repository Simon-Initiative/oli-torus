import guid from 'utils/guid';

export type DeserializerAction = (el: HTMLElement) => Record<string, unknown> | null;

export const tagTypeAction =
  (type: string): DeserializerAction =>
  () => ({ type, id: guid() });

/* Adds a static empty children array to the element */
export const addEmptyChildrenAction: DeserializerAction = () => {
  return { children: [{ text: '' }] };
};

/* Takes the given attribute from the input element, and adds it to the output node with the given name and default value
 *
 */
export const copyAttribute =
  (sourceName: string, targetName: string, defaultValue: unknown = null): DeserializerAction =>
  (el: HTMLElement) => {
    const value = el.getAttribute(sourceName);
    if (!value && !defaultValue) return null; // If there's no value and no default, don't add the attribute
    return { [targetName]: value || defaultValue };
  };

export const copyNumericAttribute =
  (sourceName: string, targetName: string, defaultValue: unknown = null): DeserializerAction =>
  (el: HTMLElement) => {
    const value = el.getAttribute(sourceName);
    if (!value && !defaultValue) return null; // If there's no value and no default, don't add the attribute
    const num = parseInt(value || (defaultValue as string), 10);
    if (isNaN(num)) return null;
    return { [targetName]: num };
  };

/* Takes the text content of the input element, and adds it as an attribute to the output node with the given name
 */
export const copyTextContent =
  (targetName: string): DeserializerAction =>
  (el: HTMLElement) => {
    const value = el.textContent;
    if (!value) return null;
    return { [targetName]: value };
  };

export const addMarkAction =
  (mark: string): DeserializerAction =>
  (el: HTMLElement) => {
    return { [mark]: true };
  };
