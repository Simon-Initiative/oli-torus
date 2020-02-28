import { Element } from 'slate';

export function create<ModelElement>(params: ModelElement): ModelElement {
  return (params as ModelElement);
}

export function mutate<ModelElement>(obj: ModelElement, changes: Object): ModelElement {
  return Object.assign({}, obj, changes) as ModelElement;
}

export type ModelElement
  = Paragraph | HeadingOne | HeadingTwo | HeadingThree
  | HeadingFour | HeadingFive | HeadingSix | Image | YouTube
  | Audio | Table | TableRow | TableHeader | TableData | OrderedList | UnorderedList
  | ListItem | Math | MathLine | Code | CodeLine | Blockquote | Hyperlink;

export interface Identifiable {
  id: string;
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
}

export interface YouTube extends Element, Identifiable {
  type: 'youtube';
  src: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: string;
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
  startingLineNumber: number;
  showNumbers: boolean;
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

export const schema = {
  p: { isVoid: false, isBlock: true },
  h1: { isVoid: false, isBlock: true },
  h2: { isVoid: false, isBlock: true },
  h3: { isVoid: false, isBlock: true },
  h4: { isVoid: false, isBlock: true },
  h5: { isVoid: false, isBlock: true },
  h6: { isVoid: false, isBlock: true },
  img: { isVoid: true, isBlock: true },
  youtube: { isVoid: true, isBlock: true },
  audio: { isVoid: true, isBlock: true },
  table: { isVoid: false, isBlock: true },
  tr: { isVoid: false, isBlock: true },
  th: { isVoid: false, isBlock: true },
  td: { isVoid: false, isBlock: true },
  ol: { isVoid: false, isBlock: true },
  ul: { isVoid: false, isBlock: true },
  li: { isVoid: false, isBlock: true },
  math: { isVoid: false, isBlock: true },
  math_line: { isVoid: false, isBlock: true, isSimpleText: true },
  code: { isVoid: false, isBlock: true },
  code_line: { isVoid: false, isBlock: true, isSimpleText: true },
  blockquote: { isVoid: false, isBlock: true },
  a: { isVoid: false, isBlock: false },
};


