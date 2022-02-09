/* eslint-disable @typescript-eslint/ban-types */
import { normalizeHref } from 'components/editing/elements/link/utils';
import { Model } from 'data/content/model/elements/factories';
import { Hyperlink, ModelElement } from 'data/content/model/elements/types';
import { Editor, Node } from 'slate';
import { jsx } from 'slate-hyperscript';

const ELEMENT_TAGS: Record<string, (...args: any) => ModelElement> = {
  A: (el: HTMLElement): Hyperlink => Model.link(el.getAttribute('href') ?? ''),
  BLOCKQUOTE: Model.blockquote,
  H1: Model.h1,
  H2: Model.h2,
  H3: Model.h2,
  H4: Model.h2,
  H5: Model.h2,
  H6: Model.h2,
  IMG: (el: HTMLElement) => Model.image(normalizeHref(el.getAttribute('src') ?? '')),
  OL: Model.ol,
  UL: Model.ul,
  LI: Model.li,
  P: Model.p,
  PRE: Model.code,
};

// COMPAT: `B` is omitted here because Google Docs uses `<b>` in weird ways.
const TEXT_TAGS: Record<string, Function> = {
  STRONG: () => ({ strong: true }),
  EM: () => ({ em: true }),
  I: () => ({ em: true }),
  SUB: () => ({ sub: true }),
  SUP: () => ({ sup: true }),
  CODE: () => ({ code: true }),
};

const deserialize = (el: HTMLElement): (Node | string | null)[] | string | null | Node => {
  if (el.nodeType === 3) {
    // text node
    return el.textContent;
  }
  if (el.nodeType !== 1) {
    // not an HTML Element of some type
    return null;
  }
  if (el.nodeName === 'BR') return '\n';

  const { nodeName } = el;
  let parent: ChildNode = el;

  if (nodeName === 'PRE' && el.childNodes[0] && el.childNodes[0].nodeName === 'CODE') {
    parent = el.childNodes[0];
  }
  let children = Array.from(parent.childNodes).map(deserialize).flat();

  if (children.length === 0) {
    children = [{ text: '' }];
  }

  if (el.nodeName === 'BODY') {
    return jsx('fragment', {}, children);
  }

  if (ELEMENT_TAGS[nodeName]) {
    const attrs = ELEMENT_TAGS[nodeName](el);
    return jsx('element', attrs, children);
  }

  if (TEXT_TAGS[nodeName]) {
    const attrs = TEXT_TAGS[nodeName](el);
    return children.map((child) => jsx('text', attrs, child));
  }

  return children;
};

export const withHtml = (editor: Editor): Editor => {
  const { insertData } = editor;

  editor.insertData = (data: DataTransfer): void => {
    const html = data.getData('text/html');

    if (html) {
      const parsed = new DOMParser().parseFromString(html, 'text/html');
      const deserialized = deserialize(parsed.body);
      Editor.insertFragment(editor, deserialized as any);
      return;
    }

    insertData(data);
  };

  return editor;
};
