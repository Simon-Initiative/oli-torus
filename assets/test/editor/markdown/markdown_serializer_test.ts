import { serializeMarkdown } from 'components/editing/markdown_editor/content_markdown_serializer';
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
});
