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

type Decoration = 'youtubeInput';

export type FormattedText = Record<'text', string> & Partial<Record<Mark | Decoration, true>>;
