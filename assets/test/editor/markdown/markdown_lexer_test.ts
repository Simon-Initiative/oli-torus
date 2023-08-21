import { createLexer } from 'components/editing/markdown_editor/content_markdown_serializer';

describe('Markdown lexer', () => {
  const lexer = createLexer();
  it('Should create a strikethrough token', () => {
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
