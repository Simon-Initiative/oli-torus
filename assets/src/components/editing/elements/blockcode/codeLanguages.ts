interface Language {
  prettyName: string;
  highlightJs: string;
  monacoMode: string;
}
const struct = (prettyName: string, highlightJs: string, monacoMode: string): Language => ({
  prettyName,
  highlightJs,
  monacoMode,
});

const languages = [
  struct('C', 'c', 'cpp'),
  struct('C#', 'csharp', 'csharp'),
  struct('C++', 'cpp', 'cpp'),
  struct('Elixir', 'elixir', 'elixir'),
  struct('Golang', 'golang', 'go'),
  // struct('Haskell', 'haskell', 'haskell'),
  struct('HTML', 'html', 'html'),
  struct('Java', 'java', 'java'),
  struct('JavaScript', 'javascript', 'javascript'),
  struct('Kotlin', 'kotlin', 'kotlin'),
  // struct('Lisp', 'lisp', 'lisp'),
  // struct('ML', 'ml', 'ocaml'),
  struct('Perl', 'perl', 'perl'),
  struct('PHP', 'php', 'php'),
  struct('Python', 'python', 'python'),
  struct('R', 'r', 'r'),
  struct('Ruby', 'ruby', 'ruby'),
  struct('SQL', 'sql', 'sql'),
  struct('Text', 'text', 'text'),
  struct('TypeScript', 'typescript', 'typescript'),
  struct('XML', 'xml', 'xml'),
];

export const CodeLanguages = {
  byPrettyName: (name: string) => {
    const plaintext = languages.find(({ prettyName }) => prettyName === 'Text');
    return (languages.find(({ prettyName }) => prettyName === name) || plaintext) as Language;
  },
  all: () => languages,
};
