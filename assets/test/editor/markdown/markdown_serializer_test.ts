import { serializeMarkdown } from 'components/editing/markdown_editor/content_markdown_serializer';
import { Model } from 'data/content/model/elements/factories';
import { AllModelElements } from 'data/content/model/elements/types';
import { expectAnyId } from '../normalize-test-utils';

describe('Markdown serializer', () => {
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
    const out = serializeMarkdown(content);
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
});
