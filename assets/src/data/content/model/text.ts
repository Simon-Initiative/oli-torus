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

export type FormattedText = {
  text: string;

  em?: true;
  strong?: true;
  mark?: true;
  del?: true;
  var?: true;
  code?: true;
  sub?: true;
  sup?: true;
};
