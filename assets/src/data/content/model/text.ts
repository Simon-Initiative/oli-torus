export type Mark =
  | 'em'
  | 'strong'
  | 'mark'
  | 'del'
  | 'var'
  | 'code'
  | 'term'
  | 'sub'
  | 'sup'
  | 'underline'
  | 'strikethrough'
  | 'foreign';

export enum Marks {
  'em',
  'strong',
  'mark',
  'del',
  'var',
  'code',
  'term',
  'sub',
  'sup',
  'underline',
  'strikethrough',
  'foreign',
}

export type FormattedText = Record<'text', string> & Partial<Record<Mark, true>>;
