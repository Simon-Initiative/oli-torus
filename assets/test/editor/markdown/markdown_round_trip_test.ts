/*
  It's important that when we serialize to markdown, and then back to our structured content, that the
  resulting structured content is the same as the original. If not, we risk a degenerate cycle where more
  and more changes are introduced with every load/save cycle.
*/
import { Descendant } from 'slate';
import { contentMarkdownDeserializer } from 'components/editing/markdown_editor/content_markdown_deserializer';
import { serializeMarkdown } from 'components/editing/markdown_editor/content_markdown_serializer';
import { Model } from 'data/content/model/elements/factories';
import { AllModelElements } from 'data/content/model/elements/types';
import { expectAnyId } from '../normalize-test-utils';

const testRoundTrip = (nodes: AllModelElements[]) => {
  const markdown = contentMarkdownDeserializer(nodes);
  expect(markdown).toBeDefined();
  const content = serializeMarkdown(markdown as string);
  expect(content).toEqual(expectAnyId(nodes as Descendant[]));
};

describe('Markdown round trip', () => {
  it('should serialize and deserialize a heading 1', () => {
    testRoundTrip([
      {
        type: 'h1',
        id: '1',
        children: [{ text: 'Heading 1' }],
      },
    ]);
  });

  it('should serialize and deserialize a heading 2', () => {
    testRoundTrip([
      {
        type: 'h2',
        id: '1',
        children: [{ text: 'Heading 2' }],
      },
    ]);
  });

  it('should serialize and deserialize a paragraph', () => {
    testRoundTrip([
      {
        type: 'p',
        id: '1',
        children: [{ text: 'Here is some paragraph text.' }],
      },
    ]);
  });

  it('should serialize and deserialize a paragraph with formatted text', () => {
    testRoundTrip([
      {
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
      },
    ]);
  });

  it('should serialize and deserialize a table', () => {
    testRoundTrip([
      Model.table([
        Model.tr([Model.th('H1'), Model.th('H2')]),
        Model.tr([Model.td('D1'), Model.td('D2')]),
      ]),
    ]);
  });
});
