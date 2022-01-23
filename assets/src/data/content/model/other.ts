export type ID = string;

export interface Identifiable {
  id: ID;
}

// float_left and float_right no longer available as options and will render as block
export type MediaDisplayMode = 'float_left' | 'float_right' | 'block';

export const CodeLanguages = [
  'Assembly',
  'C',
  'C#',
  'C++',
  'Elixir',
  'Golang',
  'Haskell',
  'HTML',
  'Java',
  'JavaScript',
  'Kotlin',
  'Lisp',
  'ML',
  'Perl',
  'PHP',
  'Python',
  'R',
  'Ruby',
  'SQL',
  'Plain Text',
  'TypeScript',
  'XML',
];
