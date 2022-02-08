interface Language {
  prettyName: string;
  highlightJs: string;
  aceMode: string;
}
const struct = (prettyName: string, highlightJs: string, aceMode: string): Language => ({
  prettyName,
  highlightJs,
  aceMode,
});

const languages = [
  struct('Assembly', 'x86asm', 'assembly_x86'),
  struct('C', 'c', 'c_cpp'),
  struct('C#', 'csharp', 'csharp'),
  struct('C++', 'cpp', 'c_cpp'),
  struct('Elixir', 'elixir', 'elixir'),
  struct('Golang', 'golang', 'golang'),
  struct('Haskell', 'haskell', 'haskell'),
  struct('HTML', 'html', 'html'),
  struct('Java', 'java', 'java'),
  struct('JavaScript', 'javascript', 'javascript'),
  struct('Kotlin', 'kotlin', 'kotlin'),
  struct('Lisp', 'lisp', 'lisp'),
  struct('ML', 'ml', 'ocaml'),
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
