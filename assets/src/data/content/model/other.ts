export type ID = string;

export interface Identifiable {
  id: ID;
}

// float_left and float_right no longer available as options and will render as block
export type MediaDisplayMode = 'float_left' | 'float_right' | 'block';

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
