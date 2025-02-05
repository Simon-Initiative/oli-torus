import { AllModelElements } from 'data/content/model/elements/types';

type SchemaKey = keyof Schema;
type ValidChildren = Partial<Record<SchemaKey, boolean>>;

const toObj = (arr: SchemaKey[]): ValidChildren =>
  arr.reduce((p: ValidChildren, c) => {
    p[c] = true;
    return p;
  }, {});

const BlockElements: SchemaKey[] = [
  'table',
  'td',
  'tc',
  'ol',
  'ul',
  'dl',
  'math',
  'math_line',
  'code_line',
  'blockquote',
  'code',
  'formula',
  'callout',
  'trigger',
];

export const SemanticElements: SchemaKey[] = [
  'callout',
  'definition',
  'figure',
  'dialog',
  'conjugation',
];

const HeadingElements: SchemaKey[] = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
const TextBlockElements: SchemaKey[] = ['p', ...HeadingElements];
const MediaElements: SchemaKey[] = ['img', 'youtube', 'audio', 'video', 'iframe'];
const SemanticChildrenElements: SchemaKey[] = [
  ...BlockElements,
  ...MediaElements,
  ...TextBlockElements,
];

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
  validChildren: toObj(['p', 'math', 'formula_inline', 'formula', ...MediaElements]),
};

const tableConjugation = {
  ...tableCell,
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

export type ModelTypes = AllModelElements['type'];
interface Schema extends Record<ModelTypes, SchemaConfig> {}
export const schema: Schema = {
  ecl: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
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
    validChildren: toObj(SemanticChildrenElements),
  },
  conjugation: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
  dialog: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj([]),
  },
  dialog_line: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj(SemanticChildrenElements),
  },
  dl: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj([]),
  },
  dt: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj(SemanticChildrenElements),
  },
  dd: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj(SemanticChildrenElements),
  },
  pronunciation: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj([]),
  },
  translation: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj([]),
  },
  meaning: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj([]),
  },
  definition: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj([]),
  },
  callout_inline: {
    isVoid: false,
    isBlock: false,
    isTopLevel: true,
    validChildren: toObj([]),
  },
  figure: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(SemanticChildrenElements),
  },

  foreign: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: toObj(['input_ref', 'img']),
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
    validChildren: toObj(['td', 'th', 'tc']),
  },
  th: tableCell,
  td: tableCell,
  tc: tableConjugation,
  ol: list,
  ul: list,
  li: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj([
      ...BlockElements,
      ...MediaElements,
      ...TextBlockElements,
      ...SemanticElements,
    ]), //toObj(['ol', 'ul']),
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
    validChildren: toObj(['code_line']),
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
  command_button: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
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
  video: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
  page_link: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
  trigger: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
};
