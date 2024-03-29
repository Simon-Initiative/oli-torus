import { Descendant } from 'slate';
import { serializeMarkdown } from 'components/editing/markdown_editor/content_markdown_serializer';
import { Model } from 'data/content/model/elements/factories';
import { AllModelElements } from 'data/content/model/elements/types';
import { expectAnyId } from '../normalize-test-utils';

describe('Markdown serializer', () => {
  it('should serialize a line break via double-spaces', () => {
    const content = `Line one  \nLine two\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'p',
          id: '1',
          children: [{ text: 'Line one' }, { text: '\n' }, { text: 'Line two' }],
          // Apparently, it is legal to have a \n within a paragraph element, but there's no good way to author one of these.
        },
      ]),
    );
  });

  it('should serialize a heading', () => {
    const content = `# This is a heading\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'h1',
          id: '1',
          children: [{ text: 'This is a heading' }],
        },
      ]),
    );
  });

  it('should serialize a list', () => {
    const content = `* This is a list item\n* This is another list item\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'ul',
          id: '1',
          children: [Model.li('This is a list item'), Model.li('This is another list item')],
        },
      ]),
    );
  });

  it('should serialize a nested list', () => {
    const content = `* This is a list item\n  1. Sub list\n  2. Sub list 2\n* This is another list item\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'ul',
          id: '1',
          children: [
            Model.li('This is a list item'),
            Model.ol([Model.li('Sub list'), Model.li('Sub list 2')]),
            Model.li('This is another list item'),
          ],
        },
      ]),
    );
  });

  it('should serialize an image', () => {
    const content = `![Alt text](https://example.com/image.png)\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        Model.p([
          {
            type: 'img',
            id: '1',
            src: 'https://example.com/image.png',
            alt: 'Alt text',
            display: 'block',
            children: [{ text: '' }],
          },
        ]),
      ]),
    );
  });

  it('should serialize a paragraph', () => {
    const content = `This is a paragraph. With multiple text nodes.\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'p',
          id: '1',
          children: [{ text: 'This is a paragraph. With multiple text nodes.' }],
        },
      ]),
    );
  });

  it('should serialize multiple paragraphs', () => {
    const content = `This is a paragraph.\n\nThis is also a paragraph.\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'p',
          id: '1',
          children: [{ text: 'This is a paragraph.' }],
        },
        {
          type: 'p',
          id: '2',
          children: [{ text: 'This is also a paragraph.' }],
        },
      ]),
    );
  });

  it('should serialize a heading', () => {
    const content = `# This is a heading\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'h1',
          id: '1',
          children: [{ text: 'This is a heading' }],
        },
      ]),
    );
  });

  it('should serialize a level 2 heading', () => {
    const content = `## This is a level 2 heading\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'h2',
          id: '1',
          children: [{ text: 'This is a level 2 heading' }],
        },
      ]),
    );
  });

  it('should serialize bold text inside a paragraph', () => {
    const content = `This is **bold** text.\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'p',
          id: '1',
          children: [{ text: 'This is ' }, { text: 'bold', strong: true }, { text: ' text.' }],
        },
      ]),
    );
  });

  it('should serialize italic text inside a paragraph', () => {
    const content = `This is *italic* text.\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'p',
          id: '1',
          children: [{ text: 'This is ' }, { text: 'italic', em: true }, { text: ' text.' }],
        },
      ]),
    );
  });

  it('should serialize strikethrough text inside a paragraph', () => {
    const content = `This is ~~strikethrough~~ text.\n\n`;
    expect(serializeMarkdown(content)).toEqual(
      expectAnyId([
        {
          type: 'p',
          id: '1',
          children: [
            { text: 'This is ' },
            { text: 'strikethrough', strikethrough: true },
            { text: ' text.' },
          ],
        },
      ]),
    );
  });

  it('should serialize a table', () => {
    const expected: AllModelElements = {
      type: 'table',
      id: '1',
      children: [
        Model.tr([Model.th('Heading 1'), Model.th('Heading 2'), Model.th('Heading 3')]),
        Model.tr([Model.td('Cell 1'), Model.td('Cell 2'), Model.td('Cell 3')]),
        Model.tr([Model.td('Cell 4'), Model.td('Cell 5'), Model.td('Cell 6')]),
      ],
    };

    const input = `| Heading 1   | Heading 2   | Heading 3   |
|-------------|-------------|-------------|
| Cell 1      | Cell 2      | Cell 3      |
| Cell 4      | Cell 5      | Cell 6      |
`;
    expect(serializeMarkdown(input)).toEqual(expectAnyId([expected]));
  });

  it('should serialize a code block', () => {
    const expected: AllModelElements = {
      type: 'code',
      id: '1',
      code: 'Some code\nSome more code',
      language: 'jsx',
      children: [{ text: '' }],
    };

    const marker = '```';
    const input = `${marker}jsx\nSome code\nSome more code\n${marker}\n\n`;
    expect(serializeMarkdown(input)).toEqual(expectAnyId([expected]));
  });

  it('should correctly handle us removing the double \n at the end of a doc', () => {
    const expected: Descendant[] = [
      {
        type: 'p',
        id: '1',
        children: [{ text: 'Here is some paragraph text.' }],
      },
      {
        type: 'p',
        id: '2',
        children: [{ text: 'Here is the second paragraph text.' }],
      },
    ];

    // Note the second paragraph doesn't have \n\n at the end, we strip those out when we deserialize
    // so the on-screen editor isn't bigger by 2 lines than it needs to be.
    const content = `Here is some paragraph text.\n\nHere is the second paragraph text.`;

    expect(serializeMarkdown(content)).toEqual(expectAnyId(expected));
  });
});
