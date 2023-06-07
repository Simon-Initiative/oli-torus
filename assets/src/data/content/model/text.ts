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
  | 'foreign'
  | 'doublesub'
  | 'deemphasis';

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
  'doublesub',
  'deemphasis',
}

export type FormattedText = Record<'text', string> & Partial<Record<Mark, true>>;
