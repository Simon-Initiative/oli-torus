import { Editor, Text, Transforms } from 'slate';
import { ModelElement } from 'data/content/model/elements/types';
import guid from 'utils/guid';

type DeserializeTypesNoNull = ModelElement | Text | (ModelElement | Text)[];
type DeserializeTypes = DeserializeTypesNoNull | null;

const filterNull = (arr: DeserializeTypes): arr is DeserializeTypesNoNull => arr != null;

type TagDeserializer = (el: HTMLElement) => Omit<ModelElement, 'children' | 'id'> | null;

const ELEMENT_TAG_DESERIALIZERS: Record<string, TagDeserializer> = {
  A: (el: HTMLElement) => ({ type: 'a', href: el.getAttribute('href') || '' }),
  // BLOCKQUOTE: () => ({ type: 'quote' }),
  H1: () => ({ type: 'h1' }),
  H2: () => ({ type: 'h2' }),
  H3: () => ({ type: 'h3' }), // Question: Should we stick with the authorable h1 & h2?
  H4: () => ({ type: 'h4' }),
  H5: () => ({ type: 'h5' }),
  H6: () => ({ type: 'h6' }),
  // IMG: (el: HTMLElement) => ({ type: 'image', url: el.getAttribute('src') }),
  // LI: () => ({ type: 'list-item' }),
  // OL: () => ({ type: 'numbered-list' }),
  P: () => ({ type: 'p' }),
  DIV: () => ({ type: 'p' }),
  // PRE: () => ({ type: 'code' }),
  // UL: () => ({ type: 'bulleted-list' }),
};

type MarkDeserializer = (el: HTMLElement) => Record<string, boolean> | null;

// COMPAT: `B` is omitted here because Google Docs uses `<b>` in weird ways.
const TEXT_TAGS: Record<string, MarkDeserializer> = {
  CODE: () => ({ code: true }),
  DEL: () => ({ strikethrough: true }),
  EM: () => ({ italic: true }),
  I: () => ({ italic: true }),
  S: () => ({ strikethrough: true }),
  STRONG: () => ({ bold: true }),
  U: () => ({ underline: true }),
};

const addToTextNode =
  (attrs: Record<string, boolean>) =>
  (node: Text | ModelElement): Text | ModelElement => {
    return Text.isText(node) ? { ...node, ...attrs } : node;
  };

// noBreakSpace = \u00a0;
const sanitizeText = (text: string) => text.replace(/\u00a0/g, ' ');

const deserialize = (el: HTMLElement): DeserializeTypes => {
  if (el.nodeType === 3 && el.textContent) {
    return [{ text: sanitizeText(el.textContent) }];
  } else if (el.nodeType !== 1) {
    return null;
  }
  // else if (el.nodeName === 'BR') {
  //   return { text: '\n' };
  // }

  const { nodeName } = el;
  let parent: ChildNode = el;

  if (nodeName === 'PRE' && el.childNodes[0] && el.childNodes[0].nodeName === 'CODE') {
    parent = el.childNodes[0];
  }

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
    return {
      ...attrs,
      children,
      id: guid(),
    } as ModelElement;
  }

  if (TEXT_TAGS[nodeName]) {
    const attrs = TEXT_TAGS[nodeName](el);
    if (attrs) {
      return children.map(addToTextNode(attrs));
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
    console.info(fragment);
    event.preventDefault();
    Transforms.insertFragment(editor, fragment);
  } catch (e) {
    console.error('Could not parse pasted html', e);
    return;
  }
};
