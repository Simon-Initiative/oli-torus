import { Editor, Text, Transforms } from 'slate';
import { ModelElement } from 'data/content/model/elements/types';
import guid from 'utils/guid';

type DeserializeTypesNoNull = ModelElement | Text | (ModelElement | Text)[];
type DeserializeTypes = DeserializeTypesNoNull | null;

const filterNull = (arr: DeserializeTypes): arr is DeserializeTypesNoNull => arr != null;

type DeserializerMatchRule = (el: HTMLElement) => boolean;

/* When you have several rules and you want to match on any of those rules.
 * const rule = anyRule(subRule1, subRule2, subRule3);
 * A logical OR of the rules.
 */
const anyRule =
  (...rules: DeserializerMatchRule[]): DeserializerMatchRule =>
  (el: HTMLElement) =>
    rules.some((rule) => rule(el));

/* When you have several rules and you only want to match on all of those rules.
 * const rule = allRules(subRule1, subRule2, subRule3);
 * A logical AND of the rules.
 **/
const allRules =
  (...rules: DeserializerMatchRule[]): DeserializerMatchRule =>
  (el: HTMLElement) =>
    rules.every((rule) => rule(el));

const notRule =
  (rule: DeserializerMatchRule): DeserializerMatchRule =>
  (el: HTMLElement) =>
    !rule(el);

/* You should be able to combine any and all rules like so:
 * const rule = anyRule([allRules([subRule1, subRule2]), subRule3]);
 */

type DeserializerAction = (el: HTMLElement) => Record<string, unknown> | null;

type PartialTagDeserializer = {
  rule: DeserializerMatchRule;
  action: DeserializerAction;
};

const hasAttributeRule =
  (attributeName: string): DeserializerMatchRule =>
  (el: HTMLElement) =>
    !!el.getAttribute(attributeName);

const attributeEqualsRule =
  (attributeName: string, attributeValue: string): DeserializerMatchRule =>
  (el: HTMLElement) =>
    el.getAttribute(attributeName) === attributeValue;

const tagNameRule =
  (tagName: string): DeserializerMatchRule =>
  (el: HTMLElement) =>
    el.tagName.toUpperCase() === tagName.toUpperCase();

const tagTypeAction =
  (type: string): DeserializerAction =>
  () => ({ type, id: guid() });

const serializer = (
  rule: DeserializerMatchRule,
  ...actions: DeserializerAction[]
): PartialTagDeserializer => {
  if (actions.length === 0) {
    throw new Error('Must have at least one action');
  }
  if (actions.length === 1) {
    return {
      rule,
      action: actions[0],
    };
  }
  return {
    rule,
    action: (el: HTMLElement) => {
      const attrs = actions.map((action) => action(el));
      return Object.assign({}, ...attrs);
    },
  };
};

/* Adds a static empty children array to the element */
const addEmptyChildrenAction: DeserializerAction = () => {
  return { children: [{ text: '' }] };
};

/* Takes the given attribute from the input element, and adds it to the output node with the given name and default value
 *
 */
const copyAttribute =
  (sourceName: string, targetName: string, defaultValue: unknown = null): DeserializerAction =>
  (el: HTMLElement) => {
    const value = el.getAttribute(sourceName);
    if (!value && !defaultValue) return null; // If there's no value and no default, don't add the attribute
    return { [targetName]: value || defaultValue };
  };

/* Takes the text content of the input element, and adds it as an attribute to the output node with the given name
 */
const copyTextContent =
  (targetName: string): DeserializerAction =>
  (el: HTMLElement) => {
    const value = el.textContent;
    if (!value) return null;
    return { [targetName]: value };
  };

const addMarkAction =
  (mark: string): DeserializerAction =>
  (el: HTMLElement) => {
    return { [mark]: true };
  };

const TAG_DESERIALIZERS: PartialTagDeserializer[] = [
  serializer(tagNameRule('A'), tagTypeAction('a'), copyAttribute('href', 'href')),
  serializer(tagNameRule('H1'), tagTypeAction('h1')),
  serializer(tagNameRule('H2'), tagTypeAction('h2')),
  serializer(tagNameRule('H3'), tagTypeAction('h3')),
  serializer(tagNameRule('H4'), tagTypeAction('h4')),
  serializer(tagNameRule('H5'), tagTypeAction('h5')),
  serializer(tagNameRule('H6'), tagTypeAction('h6')),
  serializer(tagNameRule('P'), tagTypeAction('p')),
  serializer(tagNameRule('DIV'), tagTypeAction('p')),
  serializer(
    tagNameRule('PRE'),
    tagTypeAction('code'),
    addEmptyChildrenAction,
    copyTextContent('code'),
    copyAttribute('data-language', 'language', 'text'),
  ),
  serializer(
    allRules(tagNameRule('I'), hasAttributeRule('lang')),
    tagTypeAction('foreign'),
    copyAttribute('lang', 'lang'),
  ),
];

// These deserialize tags that result in marks being applied to text nodes.
const TEXT_TAGS: PartialTagDeserializer[] = [
  serializer(tagNameRule('CODE'), addMarkAction('code')),
  serializer(tagNameRule('DEL'), addMarkAction('strikethrough')),
  serializer(tagNameRule('EM'), addMarkAction('italic')),
  serializer(
    allRules(tagNameRule('I'), notRule(hasAttributeRule('lang'))), // <i lang="fr"> is going to be treated as a <foreign> node and so don't count that as a mark
    addMarkAction('italic'),
  ),
  serializer(tagNameRule('S'), addMarkAction('strikethrough')),
  serializer(tagNameRule('STRONG'), addMarkAction('bold')),
  serializer(tagNameRule('B'), addMarkAction('bold')),
  serializer(tagNameRule('U'), addMarkAction('underline')),
  serializer(tagNameRule('SUB'), addMarkAction('sub')),
  serializer(tagNameRule('SUP'), addMarkAction('sup')),
  serializer(tagNameRule('SMALL'), addMarkAction('deemphasis')),
];

const addToTextNode =
  (attrs: Record<string, boolean>) =>
  (node: Text | ModelElement): Text | ModelElement => {
    if (!Text.isText(node)) return node; // QUESTION: Do we need to recursively follow children of elements and set their children too?

    // Special case: if we're adding subscript to a node with subscript, it's double sub script instead
    if (attrs.sub && node.sub) {
      delete attrs.sub;
      delete node.sub;
      attrs.doublesub = true;
    }

    // Special case: if we're adding subscript to a node with double subscript, ignore it
    if (attrs.sub && node.doublesub) {
      delete attrs.sub;
    }

    return { ...node, ...attrs };
  };

const sanitizeText = (text: string) => text.replace(/[\u00a0]/g, ' ').replace(/[\n\r]+/g, ' ');

const deserialize = (el: HTMLElement): DeserializeTypes => {
  if (el.nodeType === 3 && el.textContent) {
    return [{ text: sanitizeText(el.textContent) }];
  } else if (el.nodeType !== 1) {
    return null;
  }

  const { nodeName } = el;
  const parent: ChildNode = el;

  let children: DeserializeTypesNoNull = Array.from(parent.childNodes)
    .map(deserialize)
    .filter(filterNull)
    .flat();

  if (children.length === 0) {
    children = [{ text: '' }];
  }

  if (nodeName === 'BODY') {
    return children;
  }

  /* Run through all our TEXT_TAGS rules and collect all the results from them for this element.
     These are going to be marks we add to the text nodes that are children of this element.
  */
  const textAttributesArray = TEXT_TAGS.filter(({ rule }) => rule(el))
    .map(({ action }) => action(el))
    .filter((r) => r != null);
  const textAttributes = Object.assign({}, ...textAttributesArray);
  if (textAttributes) {
    children = children.map(addToTextNode(textAttributes));
  }

  /* Run through all our TAG_DESERIALIZER rules and collect all the results from them for this element. */
  const elementAttributesArray = TAG_DESERIALIZERS.filter(({ rule }) => rule(el))
    .map(({ action }) => action(el))
    .filter((r) => r != null);
  const elementAttributes = Object.assign({}, ...elementAttributesArray);

  /* We our rules added a type prop (and maybe lots of other stuff) to the elementAttributes, we're going to treat it as an element.
     If we have a children prop, we're good to go (ex: the code node will want an empty children array and adds that in the rules)
     If not, we need to add that in.
  */
  if (elementAttributes.type) {
    if (!elementAttributes.children) {
      elementAttributes.children = children;
    }
    return elementAttributes as ModelElement;
  }

  return children;
};

export const onHTMLPaste = (event: React.ClipboardEvent<HTMLDivElement>, editor: Editor) => {
  const pastedHtml = event.clipboardData?.getData('text/html')?.trim();

  if (!pastedHtml) return;

  try {
    const parsed = new DOMParser().parseFromString(pastedHtml, 'text/html');
    const [body] = Array.from(parsed.getElementsByTagName('body'));
    let fragment = deserialize(body);

    if (!fragment) return;
    if (!Array.isArray(fragment)) fragment = [fragment];
    event.preventDefault();
    Transforms.insertFragment(editor, fragment);
  } catch (e) {
    console.error('Could not parse pasted html', e);
    return;
  }
};
