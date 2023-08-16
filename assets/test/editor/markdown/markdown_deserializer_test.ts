import {
  DeserializationContext,
  contentMarkdownDeserializer,
  deserializeNode,
} from 'components/editing/markdown_editor/content_markdown_deserializer';
import { AllModelElements } from 'data/content/model/elements/types';

const emptyContext: DeserializationContext = {
  nodeStack: [],
  listStack: [],
};

Object.freeze(emptyContext);

describe('Markdown Deserializer', () => {
  it('should deserialize a paragraph', () => {
    const content: AllModelElements[] = [
      {
        type: 'p',
        id: '1',
        children: [{ text: 'This is a paragraph. ' }, { text: 'With multiple text nodes.' }],
      },
    ];
    expect(contentMarkdownDeserializer(content)).toEqual(
      `This is a paragraph. With multiple text nodes.\n\n`,
    );
  });

  it('should deserialize multiple paragraphs', () => {
    const content: AllModelElements[] = [
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
    ];
    expect(contentMarkdownDeserializer(content)).toEqual(
      `This is a paragraph.\n\nThis is also a paragraph.\n\n`,
    );
  });

  it('should deserialize a heading 1', () => {
    const node: AllModelElements = {
      type: 'h1',
      id: '1',
      children: [{ text: 'Heading 1' }],
    };
    const expectedOutput = `# Heading 1\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a heading 2', () => {
    const node: AllModelElements = {
      type: 'h2',
      id: '1',
      children: [{ text: 'Heading 2' }],
    };
    const expectedOutput = `## Heading 2\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a heading 3', () => {
    const node: AllModelElements = {
      type: 'h3',
      id: '1',
      children: [{ text: 'Heading 3' }],
    };
    const expectedOutput = `### Heading 3\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a heading 4', () => {
    const node: AllModelElements = {
      type: 'h4',
      id: '1',
      children: [{ text: 'Heading 4' }],
    };
    const expectedOutput = `#### Heading 4\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a heading 5', () => {
    const node: AllModelElements = {
      type: 'h5',
      id: '1',
      children: [{ text: 'Heading 5' }],
    };
    const expectedOutput = `##### Heading 5\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a heading 6', () => {
    const node: AllModelElements = {
      type: 'h6',
      id: '1',
      children: [{ text: 'Heading 6' }],
    };
    const expectedOutput = `###### Heading 6\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a paragraph', () => {
    const node: AllModelElements = {
      type: 'p',
      id: '1',
      children: [{ text: 'This is a paragraph. ' }, { text: 'With multiple text nodes.' }],
    };
    const expectedOutput = `This is a paragraph. With multiple text nodes.\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize an unordered list', () => {
    const node: AllModelElements = {
      type: 'ul',
      id: '1',
      children: [
        {
          type: 'li',
          id: '2',
          children: [{ type: 'p', id: '4', children: [{ text: 'Item 1' }] }],
        },
        {
          type: 'li',
          id: '3',
          children: [{ type: 'p', id: '5', children: [{ text: 'Item 2' }] }],
        },
      ],
    };
    const expectedOutput = `- Item 1\n- Item 2\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize an ordered list', () => {
    const node: AllModelElements = {
      type: 'ol',
      id: '1',
      children: [
        {
          type: 'li',
          id: '2',
          children: [{ type: 'p', id: '5', children: [{ text: 'Item 1' }] }],
        },
        {
          type: 'li',
          id: '3',
          children: [{ type: 'p', id: '5', children: [{ text: 'Item 2' }] }],
        },
      ],
    };
    const expectedOutput = `1. Item 1\n2. Item 2\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should indent nested list children', () => {
    const node: AllModelElements = {
      type: 'ul',
      id: '200',
      children: [
        {
          type: 'li',
          id: '300',
          children: [{ type: 'p', id: '4', children: [{ text: 'Item 1' }] }],
        },
        {
          type: 'ol',
          id: '100',
          children: [
            {
              type: 'li',
              id: '2',
              children: [
                { type: 'p', id: '4', children: [{ text: 'Para 1' }] },
                { type: 'p', id: '5', children: [{ text: 'Para 2' }] },
              ],
            },
            {
              type: 'ul',
              id: '400',
              children: [
                {
                  type: 'li',
                  id: '5',
                  children: [
                    { type: 'p', id: '4', children: [{ text: 'Para 3' }] },
                    { type: 'p', id: '5', children: [{ text: 'Para 4' }] },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };
    /*
    - Item 1
      1. Para 1
      Para 2
        - Para 3
        Para 4
    */
    const expectedOutput = `- Item 1\n  1. Para 1\n  Para 2\n    - Para 3\n    Para 4\n\n`;
    const output = deserializeNode(emptyContext)(node);
    expect(output).toEqual(expectedOutput);
  });

  it('should deserialize a blockquote', () => {
    const context: DeserializationContext = {
      nodeStack: [],
      listStack: [],
    };
    const node: AllModelElements = {
      type: 'blockquote',
      id: '1',
      children: [
        {
          type: 'p',
          id: '2',
          children: [{ text: 'This is a blockquote.' }],
        },
      ],
    };
    const expectedOutput = `> This is a blockquote.\n\n`;
    expect(deserializeNode(context)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a link', () => {
    const context: DeserializationContext = {
      nodeStack: [],
      listStack: [],
    };
    const node: AllModelElements = {
      type: 'a',
      id: '1',
      href: 'https://example.com',
      children: [{ text: 'Example' }],
    };
    const expectedOutput = `[Example](https://example.com)`;
    expect(deserializeNode(context)(node)).toEqual(expectedOutput);
  });

  it('should deserialize an image', () => {
    const context: DeserializationContext = {
      nodeStack: [],
      listStack: [],
    };
    const node: AllModelElements = {
      type: 'img',
      id: '1',
      src: 'https://example.com/image.png',
      caption: 'Example Image',
      children: [{ text: '' }],
    };
    const expectedOutput = `![Example Image](https://example.com/image.png)`;
    expect(deserializeNode(context)(node)).toEqual(expectedOutput);
  });
});
