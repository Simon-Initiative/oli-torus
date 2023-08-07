import { Text } from 'slate';
import { ModelElement } from 'data/content/model/elements/types';

/*
  These are a flexible set of building blocks for rules that matching HTML elements in our deserializer.
*/

export type DeserializeTypesNoNull = ModelElement | Text | (ModelElement | Text)[];
export type DeserializeTypes = DeserializeTypesNoNull | null;

export type DeserializerMatchRule = (el: HTMLElement) => boolean;

/* When you have several rules and you want to match on any of those rules.
 * const rule = anyRule(subRule1, subRule2, subRule3);
 * A logical OR of the rules.
 */
export const anyRule =
  (...rules: DeserializerMatchRule[]): DeserializerMatchRule =>
  (el: HTMLElement) =>
    rules.some((rule) => rule(el));

/* When you have several rules and you only want to match on all of those rules.
 * const rule = allRules(subRule1, subRule2, subRule3);
 * A logical AND of the rules.
 **/
export const allRules =
  (...rules: DeserializerMatchRule[]): DeserializerMatchRule =>
  (el: HTMLElement) =>
    rules.every((rule) => rule(el));

export const notRule =
  (rule: DeserializerMatchRule): DeserializerMatchRule =>
  (el: HTMLElement) =>
    !rule(el);

/* You should be able to combine any and all rules like so:
 * const rule = anyRule([allRules([subRule1, subRule2]), subRule3]);
 */

export const hasAttributeRule =
  (attributeName: string): DeserializerMatchRule =>
  (el: HTMLElement) =>
    !!el.getAttribute(attributeName);

export const attributeEqualsRule =
  (attributeName: string, attributeValue: string): DeserializerMatchRule =>
  (el: HTMLElement) => {
    const value = el.getAttribute(attributeName);
    if (!value) return false;

    if (attributeValue === 'normal') {
      debugger;
    }

    if (typeof value === 'string' && typeof attributeValue === 'string') {
      return value.toLowerCase() === attributeValue.toLowerCase();
    }

    return value === attributeValue;
  };

export const tagNameRule =
  (tagName: string): DeserializerMatchRule =>
  (el: HTMLElement) =>
    el.tagName.toUpperCase() === tagName.toUpperCase();

export type StyleMatcher = (style: string) => boolean;

export const styleRule =
  (styleName: string, styleValue: string[] | string | StyleMatcher): DeserializerMatchRule =>
  (el: HTMLElement) => {
    const style = el.style[styleName as any];
    if (typeof styleValue === 'string') {
      return style === styleValue;
    }
    if (Array.isArray(styleValue)) {
      return styleValue.includes(style);
    }
    return styleValue(style);
  };
