import { createLexer } from 'components/editing/markdown_editor/content_markdown_serializer';

describe('Markdown lexer', () => {
  it('should create a codeblock token', () => {
    const lexer = createLexer();
    const content = '```\nThis is a codeblock\nwith multiple lines\n```';
    const result = Array.from(lexer.lex(content));
    expect(result).toEqual([
      {
        type: 'code',
        raw: '```\nThis is a codeblock\nwith multiple lines\n```',
        lang: '',
        text: 'This is a codeblock\nwith multiple lines',
      },
    ]);
  });

  it('should create an inline code token', () => {
    const lexer = createLexer();
    const content = 'Here is some `code` to read.';
    const result = Array.from(lexer.lex(content));
    expect(result).toEqual([
      {
        type: 'paragraph',
        raw: 'Here is some `code` to read.',
        text: 'Here is some `code` to read.',
        tokens: [
          {
            type: 'text',
            raw: 'Here is some ',
            text: 'Here is some ',
          },
          {
            type: 'codespan',
            raw: '`code`',
            text: 'code',
          },
          {
            type: 'text',
            raw: ' to read.',
            text: ' to read.',
          },
        ],
      },
    ]);
  });

  it('Should create a strikethrough token', () => {
    const lexer = createLexer();
    const content = `~~This is a strikethrough~~`;
    const result = Array.from(lexer.lex(content));
    expect(result).toEqual([
      {
        type: 'paragraph',
        raw: '~~This is a strikethrough~~',
        text: '~~This is a strikethrough~~',
        tokens: [
          {
            type: 'del',
            raw: '~~This is a strikethrough~~',
            text: 'This is a strikethrough',
            tokens: [
              {
                type: 'text',
                raw: 'This is a strikethrough',
                text: 'This is a strikethrough',
              },
            ],
          },
        ],
      },
    ]);
  });
});
