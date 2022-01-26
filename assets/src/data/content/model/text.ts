export type Mark =
  | 'em'
  | 'strong'
  | 'mark'
  | 'del'
  | 'var'
  | 'code'
  | 'sub'
  | 'sup'
  | 'underline'
  | 'strikethrough';

export enum Marks {
  'em',
  'strong',
  'mark',
  'del',
  'var',
  'code',
  'sub',
  'sup',
  'underline',
  'strikethrough',
}

type Decoration = 'youtubeInput' | 'placeholder';

export type FormattedText = Record<'text', string> & Partial<Record<Mark | Decoration, true>>;
