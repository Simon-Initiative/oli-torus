import { Element, Range } from 'slate';
import guid from 'utils/guid';
import { normalizeHref } from 'components/editing/models/link/utils';

export function create<ModelElement>(params: Partial<ModelElement>): ModelElement {
  return Object.assign({
    id: guid(),
    children: [{ text: '' }],
  } as any, params) as ModelElement;
}

// Helper functions for creating ModelElements
export const td = (text: string) =>
  create<TableData>({ type: 'td', children: [{ type: 'p', children: [{ text }] }] });
export const tr = (children: TableData[]) => create<TableRow>({ type: 'tr', children });
export const table = (children: TableRow[]) => create<Table>({ type: 'table', children });
export const li = () => create<ListItem>({ type: 'li' });
export const ol = () => create<OrderedList>({ type: 'ol', children: [li()] });
export const ul = () => create<UnorderedList>({ type: 'ul', children: [li()] });
export const youtube = (src: string) => create<YouTube>({ type: 'youtube', src });
export const webpage = (src: string) => create<Webpage>({ type: 'iframe', src });
export const link = (href = '') => create<Hyperlink>({ type: 'a', href: normalizeHref(href), target: 'self' });
export const image = (src = '') => create<Image>({ type: 'img', src, display: 'block' });
export const audio = (src = '') => create<Audio>({ type: 'audio', src });
export const p = () => create<Paragraph>({ type: 'p' });
export const code = () => ({
  type: 'code',
  language: 'python',
  children: [{ type: 'code_line', children: [{ text: '' }] }],
});

// eslint-disable-next-line
export function mutate<ModelElement>(obj: ModelElement, changes: Object): ModelElement {
  return Object.assign({}, obj, changes) as ModelElement;
}

export type Selection = Range | null;

// float_left and float_right no longer available as options and will render as block
export type MediaDisplayMode = 'float_left' | 'float_right' | 'block';

export type ModelElement
  = Paragraph | HeadingOne | HeadingTwo | HeadingThree
  | HeadingFour | HeadingFive | HeadingSix | Image | YouTube | Webpage
  | Audio | Table | TableRow | TableHeader | TableData | OrderedList | UnorderedList
  | ListItem | Math | MathLine | Code | CodeLine | Blockquote | Hyperlink;

export type TextElement = Paragraph | HeadingOne | HeadingTwo | HeadingThree
  | HeadingFour | HeadingFive | HeadingSix;

export type ID = string;

export interface Identifiable {
  id: ID;
}

export interface Paragraph extends Element, Identifiable {
  type: 'p';
}

export interface HeadingOne extends Element, Identifiable {
  type: 'h1';
}

export interface HeadingTwo extends Element, Identifiable {
  type: 'h2';
}

export interface HeadingThree extends Element, Identifiable {
  type: 'h3';
}

export interface HeadingFour extends Element, Identifiable {
  type: 'h4';
}

export interface HeadingFive extends Element, Identifiable {
  type: 'h5';
}

export interface HeadingSix extends Element, Identifiable {
  type: 'h6';
}

export interface Image extends Element, Identifiable {
  type: 'img';
  src: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: string;
  display?: MediaDisplayMode;
}

export interface YouTube extends Element, Identifiable {
  type: 'youtube';
  src: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: string;
  display?: MediaDisplayMode;
}

// tslint:disable-next-line: class-name
export interface Webpage extends Element, Identifiable {
  type: 'iframe';
  src: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: string;
  display?: MediaDisplayMode;
}

export interface Audio extends Element, Identifiable {
  type: 'audio';
  src: string;
  alt?: string;
  caption?: string;
}

export interface Table extends Element, Identifiable {
  type: 'table';
  caption?: string;
}

export interface TableRow extends Element, Identifiable {
  type: 'tr';
}

export interface TableHeader extends Element, Identifiable {
  type: 'th';
}

export interface TableData extends Element, Identifiable {
  type: 'td';
}

export interface OrderedList extends Element, Identifiable {
  type: 'ol';
}

export interface UnorderedList extends Element, Identifiable {
  type: 'ul';
}

export interface ListItem extends Element, Identifiable {
  type: 'li';
}

export interface Math extends Element, Identifiable {
  type: 'math';
}

export interface MathLine extends Element, Identifiable {
  type: 'math_line';
}

export interface Code extends Element, Identifiable {
  type: 'code';
  language: string;
  caption?: string;
}

export interface CodeLine extends Element, Identifiable {
  type: 'code_line';
}

export interface Blockquote extends Element, Identifiable {
  type: 'blockquote';
}

// Inlines

export interface Hyperlink extends Element, Identifiable {
  type: 'a';
  href: string;
  target: string;
}

export type Mark = 'em' | 'strong' | 'mark' | 'del' | 'var' | 'code' | 'sub' | 'sup';

export enum Marks {
  'em',
  'strong',
  'mark',
  'del',
  'var',
  'code',
  'sub',
  'sup',
}

export enum CodeLanguages {
  'none',
  'python',
  'java',
  'javascript',
  'cpp',
  'c',
  'c0',
  'c#',
  'erlang',
  'elixir',
  'lisp',
  'ml',
  'sql',
  'perl',
  'php',
  'r',
  'scala',
  'swift',
  'ruby',
  'ocaml',
  'haskell',
  'rust',
  'golang',
  'text',
  'xml',
  'html',
  'assembly',
  'kotlin',
  'f#',
  'typescript',
  'dart',
  'clojure',
}

const toObj = (arr: string[]) => arr
  .reduce((p: unknown, c: string) => { (p as any)[c] = true; return p; }, {});

export type SchemaConfig = {
  isVoid: boolean,
  isBlock: boolean,
  isTopLevel: boolean,
  // eslint-disable-next-line
  validChildren: Object,
};

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
  validChildren: toObj(['p', 'img', 'youtube', 'audio', 'math']),
};

const list = {
  isVoid: false,
  isBlock: true,
  isTopLevel: true,
  validChildren: toObj(['li', 'ol', 'ul']),
};

export const schema = {
  p: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
  h1: header,
  h2: header,
  h3: header,
  h4: header,
  h5: header,
  h6: header,
  img: media,
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
    isVoid: false,
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
  a: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
};


