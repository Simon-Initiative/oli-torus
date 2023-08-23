import {
  DeserializationContext,
  contentMarkdownDeserializer,
  deserializeNode,
} from 'components/editing/markdown_editor/content_markdown_deserializer';
import { Model } from 'data/content/model/elements/factories';
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

  it('should deserialize some inline marks', () => {
    const node: AllModelElements = {
      type: 'p',
      id: '1',
      children: [
        { text: 'Here is a paragraph with some ' },
        { strong: true, text: 'bold' },
        { text: ' ' },
        { em: true, text: 'italic' },
        { text: ' ' },
        { strikethrough: true, text: 'and strikethrough' },
        { text: ' text in it.' },
      ],
    };

    const expectedOutput = `Here is a paragraph with some **bold** _italic_ ~~and strikethrough~~ text in it.\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize nested marks', () => {
    const node: AllModelElements = {
      type: 'p',
      id: '1',
      children: [
        { text: 'Here is a paragraph with some ' },
        { strong: true, em: true, text: 'bold italic' },
        { text: ' text in it.' },
      ],
    };

    const expectedOutput = `Here is a paragraph with some **_bold italic_** text in it.\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a table', () => {
    const node: AllModelElements = {
      type: 'table',
      id: '1',
      children: [
        Model.tr([Model.th('Heading 1'), Model.th('Heading 2'), Model.th('Heading 3')]),
        Model.tr([Model.td('Cell 1'), Model.td('Cell 2'), Model.td('Cell 3')]),
        Model.tr([Model.td('Cell 4'), Model.td('Cell 5'), Model.td('Cell 6')]),
      ],
    };

    const expectedOutput = `| Heading 1   | Heading 2   | Heading 3   |
|-------------|-------------|-------------|
| Cell 1      | Cell 2      | Cell 3      |
| Cell 4      | Cell 5      | Cell 6      |

`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });

  it('should deserialize a code block', () => {
    const node: AllModelElements = {
      type: 'code',
      id: '1',
      code: 'Some code\nSome more code',
      language: 'Text',
      children: [{ text: '' }],
    };

    const expectedOutput = `\`\`\`Text\nSome code\nSome more code\n\`\`\`\n\n`;
    expect(deserializeNode(emptyContext)(node)).toEqual(expectedOutput);
  });
});
