import { Editor, Text, Transforms } from 'slate';
import { ModelElement } from 'data/content/model/elements/types';
import guid from 'utils/guid';

type DeserializeTypesNoNull = ModelElement | Text | (ModelElement | Text)[];
type DeserializeTypes = DeserializeTypesNoNull | null;

const filterNull = (arr: DeserializeTypes): arr is DeserializeTypesNoNull => arr != null;

type PartialTagDeserializer = (el: HTMLElement) => Omit<ModelElement, 'children' | 'id'> | null;
type TagDeserializer = (el: HTMLElement) => ModelElement | null;

const foreignTagDeserializer: PartialTagDeserializer = (el: HTMLElement) => {
  const lang = el.getAttribute('lang');
  if (!lang) return null;
  return { type: 'foreign', lang: lang };
};

// These deserialize elements that have children appended to them automatically
const ELEMENT_TAG_DESERIALIZERS: Record<string, PartialTagDeserializer> = {
  A: (el: HTMLElement) => ({ type: 'a', href: el.getAttribute('href') || '' }),
  // BLOCKQUOTE: () => ({ type: 'quote' }),
  H1: () => ({ type: 'h1' }),
  H2: () => ({ type: 'h2' }),
  H3: () => ({ type: 'h3' }), // Question: Should we stick with the authorable h1 & h2?
  H4: () => ({ type: 'h4' }),
  H5: () => ({ type: 'h5' }),
  H6: () => ({ type: 'h6' }),
  P: () => ({ type: 'p' }),
  DIV: () => ({ type: 'p' }),
  I: foreignTagDeserializer,

  // IMG: (el: HTMLElement) => ({ type: 'image', url: el.getAttribute('src') }),
  // LI: () => ({ type: 'list-item' }),
  // OL: () => ({ type: 'numbered-list' }),
  // UL: () => ({ type: 'bulleted-list' }),
};

type MarkDeserializer = (el: HTMLElement) => Record<string, boolean> | null;

// These deserialize tags that result in marks being applied to text nodes.
const TEXT_TAGS: Record<string, MarkDeserializer> = {
  CODE: () => ({ code: true }),
  DEL: () => ({ strikethrough: true }),
  EM: () => ({ italic: true }),
  I: () => ({ italic: true }),
  S: () => ({ strikethrough: true }),
  STRONG: () => ({ bold: true }),
  B: () => ({ bold: true }),
  U: () => ({ underline: true }),
  SUB: () => ({ sub: true }),
  SUP: () => ({ sup: true }),
  SMALL: () => ({ deemphasis: true }),
};

// These deserialize tags that should not have children appended to them
const CHILDLESS_TAGS: Record<string, TagDeserializer> = {
  PRE: (el: HTMLElement) => {
    const code = el.textContent;
    const language = el.getAttribute('data-language');
    if (!code) return null;
    return {
      type: 'code',
      code,
      language: language || 'text',
      id: guid(),
      children: [{ text: '' }],
    };
  },
};

const addToTextNode =
  (attrs: Record<string, boolean>) =>
  (node: Text | ModelElement): Text | ModelElement => {
    if (!Text.isText(node)) return node;

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

// noBreakSpace = \u00a0;
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

  if (el.nodeName === 'BODY') {
    return children;
  }

  if (ELEMENT_TAG_DESERIALIZERS[nodeName]) {
    const attrs = ELEMENT_TAG_DESERIALIZERS[nodeName](el);
    if (attrs) {
      return {
        ...attrs,
        children,
        id: guid(),
      } as ModelElement;
    }
  }

  if (TEXT_TAGS[nodeName]) {
    const attrs = TEXT_TAGS[nodeName](el);
    if (attrs) {
      return children.map(addToTextNode(attrs));
    }
  }

  if (CHILDLESS_TAGS[nodeName]) {
    const node = CHILDLESS_TAGS[nodeName](el);
    if (node) {
      return node;
    }
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
