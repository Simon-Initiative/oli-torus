export const LANGUAGE_CODE_TYPES = {
  c: { value: 'C', visible: 'C' },
  'c#': { value: 'C#', visible: 'C#' },
  'c++': { value: 'C++', visible: 'C++' },
  elixir: { value: 'Elixir', visible: 'Elixir' },
  golang: { value: 'Golang', visible: 'Golang' },
  html: { value: 'HTML', visible: 'HTML' },
  java: { value: 'Java', visible: 'Java' },
  java_script: { value: 'JavaScript', visible: 'JavaScript' },
  kotlin: { value: 'Kotlin', visible: 'Kotlin' },
  perl: { value: 'Perl', visible: 'Perl' },
  php: { value: 'PHP', visible: 'PHP' },
  python: { value: 'Python', visible: 'Python' },
  r: { value: 'R', visible: 'R' },
  ruby: { value: 'Ruby', visible: 'Ruby' },
  sql: { value: 'SQL', visible: 'SQL' },
  text: { value: 'Text', visible: 'Text' },
  typescript: { value: 'TypeScript', visible: 'TypeScript' },
  xml: { value: 'XML', visible: 'XML' },
} as const;

export type LanguageCodeType = keyof typeof LANGUAGE_CODE_TYPES;
