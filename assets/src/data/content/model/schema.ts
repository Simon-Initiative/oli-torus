import { ModelElement } from 'data/content/model/elements/types';

type ValidChildren = Partial<Record<keyof Schema, boolean>>;
const toObj = (arr: (keyof Schema)[]): ValidChildren =>
  arr.reduce((p: ValidChildren, c) => {
    p[c] = true;
    return p;
  }, {});

const header = {
  isVoid: false,
  isBlock: true,
  isTopLevel: true,
  validChildren: {},
};

const media = {
  isVoid: true,
  isBlock: true,
  isTopLevel: true,
  validChildren: {},
};

const tableCell = {
  isVoid: false,
  isBlock: true,
  isTopLevel: false,
  validChildren: toObj(['p', 'img', 'youtube', 'audio', 'math', 'formula_inline', 'formula']),
};

const list = {
  isVoid: false,
  isBlock: true,
  isTopLevel: true,
  validChildren: toObj(['li', 'ol', 'ul']),
};

export interface SchemaConfig {
  isVoid: boolean;
  isBlock: boolean;
  isTopLevel: boolean;
  validChildren: ValidChildren;
  isSimpleText?: boolean;
}

interface Schema extends Record<ModelElement['type'], SchemaConfig> {}
export const schema: Schema = {
  p: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['input_ref', 'img', 'formula_inline', 'callout_inline']),
  },
  h1: header,
  h2: header,
  h3: header,
  h4: header,
  h5: header,
  h6: header,
  img: media,
  img_inline: {
    isVoid: true,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
  callout: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj([
      'p',
      'img',
      'youtube',
      'audio',
      'code',
      'blockquote',
      'iframe',
      'ol',
      'ul',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
    ]),
  },
  callout_inline: {
    isVoid: false,
    isBlock: false,
    isTopLevel: true,
    validChildren: toObj([]),
  },
  formula: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['input_ref', 'img']),
  },
  formula_inline: {
    isVoid: true,
    isBlock: false,
    isTopLevel: false,
    validChildren: toObj(['input_ref', 'img']),
  },
  youtube: media,
  audio: media,
  iframe: media,
  table: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['tr']),
  },
  tr: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj(['td', 'th']),
  },
  th: tableCell,
  td: tableCell,
  ol: list,
  ul: list,
  li: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj(['ol', 'ul']),
  },
  math: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['math_line']),
  },
  math_line: {
    isVoid: false,
    isBlock: true,
    isSimpleText: true,
    isTopLevel: false,
    validChildren: {},
  },
  code: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
  code_line: {
    isVoid: false,
    isBlock: true,
    isSimpleText: true,
    isTopLevel: false,
    validChildren: {},
  },
  blockquote: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['p']),
  },
  a: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
  cite: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
  popup: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
  input_ref: {
    isVoid: true,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
};
