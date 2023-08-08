import { Model } from 'data/content/model/elements/factories';
import {
  expectAnyEmptyParagraph,
  expectAnyId,
  expectConsoleMessage,
  runNormalizer,
} from './normalize-test-utils';

describe('List normalization', () => {
  it('should not touch non-lists', () => {
    const original = [Model.p('Hello World')];
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(original);
  });

  it('should not touch well formed lists', () => {
    const original = [
      Model.p('Hello World'),
      Model.ul([Model.li('Hello List World 1'), Model.li('Hello list World 2')]),
      Model.p('Goodbye World'),
    ];
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(original);
  });

  it('should wrap text nodes inside list items with a p', () => {
    const original = [
      Model.p(''),
      Model.ul([
        {
          ...Model.li(),
          children: [{ text: 'Hello World' } as any],
        },
      ]),
      Model.p(''),
    ];
    const { editor, consoleWarnCalls } = runNormalizer(original);

    expectConsoleMessage(
      'Normalizing content: Had an LI with all inline elements. Wrapping children in paragraph',
      consoleWarnCalls,
    );

    expect(editor.children[1]).toEqual(expectAnyId(Model.ul([Model.li([Model.p('Hello World')])])));
  });

  it('should wrap multiple text nodes inside list items with a single p', () => {
    const original = [
      Model.p(''),
      Model.ul([
        {
          ...Model.li(),
          children: [{ text: 'Hello World 1' } as any, { text: ' Hello World 2' } as any],
        },
      ]),
      Model.p(''),
    ];
    const { editor, consoleWarnCalls } = runNormalizer(original);

    expectConsoleMessage(
      'Normalizing content: Had an LI with all inline elements. Wrapping children in paragraph',
      consoleWarnCalls,
    );

    expect(editor.children[1]).toEqual(
      expectAnyId(Model.ul([Model.li([Model.p('Hello World 1 Hello World 2')])])), // Note: Slate also combines adjacent text nodes with the same marks
    );
  });

  it('should wrap multiple text nodes with different marks inside list items with a single p', () => {
    const original = [
      Model.p(''),
      Model.ul([
        {
          ...Model.li(),
          children: [
            { text: 'Hello World 1', strong: true } as any,
            { text: 'Hello World 2', em: true } as any,
          ],
        },
      ]),
      Model.p(''),
    ];

    const { editor, consoleWarnCalls } = runNormalizer(original);

    expectConsoleMessage(
      'Normalizing content: Had an LI with all inline elements. Wrapping children in paragraph',
      consoleWarnCalls,
    );

    expect(editor.children[1]).toEqual(
      expectAnyId(
        Model.ul([
          Model.li([
            Model.p([
              { text: 'Hello World 1', strong: true },
              { text: 'Hello World 2', em: true },
            ]),
          ]),
        ]),
      ),
    );
  });

  it('removes mixed block and inline children in list items', () => {
    const original = [
      Model.p(''),
      Model.ul([
        {
          ...Model.li(),
          children: [
            Model.p('Hello World 1'),
            { text: 'Hello World 2', bold: true } as any,
            { text: 'Hello World 3', italic: true } as any,
          ],
        },
      ]),
      Model.p(''),
    ];

    const { editor } = runNormalizer(original);

    expect(editor.children).toEqual(
      expectAnyId([
        expectAnyEmptyParagraph,
        Model.ul([Model.li('Hello World 1')]),
        expectAnyEmptyParagraph,
      ]),
    );
  });

  it('preserves a popup in a list item', () => {
    // Simulates MER-2448
    const originalPopup = {
      children: [
        {
          text: 'por ejemplo',
        },
      ],
      content: [
        {
          children: [
            {
              text: 'for example',
            },
          ],
          id: '998512574',
          type: 'p',
        },
      ],
      id: '1636902826',
      trigger: 'hover',
      type: 'popup',
    };

    const original = [
      Model.p(''),
      Model.ul([
        {
          ...Model.li(),
          children: [{ text: '' } as any, originalPopup, { text: '' } as any],
        },
      ]),
      Model.p(''),
    ];

    const { editor } = runNormalizer(original);

    expect(editor.children[1]).toEqual({
      type: 'ul',
      id: expect.any(String),
      children: [
        {
          type: 'li',
          id: expect.any(String),
          children: [
            {
              type: 'p',
              id: expect.any(String),
              children: [{ text: '' }, originalPopup, { text: '' }],
            },
          ],
        },
      ],
    });
  });

  it('should force list items within an ul list', () => {
    const original = [
      Model.p(),
      Model.ul([Model.p('Hello List World 1') as any, Model.li('Hello list World 2')]),
      Model.p(),
    ];
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(
      expectAnyId([
        expectAnyEmptyParagraph,
        Model.ul([
          Model.li([Model.p('Hello List World 1')]),
          Model.li([Model.p('Hello list World 2')]),
        ]),
        expectAnyEmptyParagraph,
      ]),
    );
  });

  it('should force list items within an ol list', () => {
    const original = [
      Model.p(),
      Model.ol([Model.p('Hello List World 1') as any, Model.li('Hello list World 2')]),
      Model.p(),
    ];
    const { editor, consoleWarnCalls } = runNormalizer(original);
    expectConsoleMessage(
      'Normalizing content: Wrapping node in list to list item type',
      consoleWarnCalls,
    );
    expect(editor.children).toEqual(
      expectAnyId([
        expectAnyEmptyParagraph,
        Model.ol([
          Model.li([Model.p('Hello List World 1')]),
          Model.li([Model.p('Hello list World 2')]),
        ]),
        expectAnyEmptyParagraph,
      ]),
    );
  });
});

it('should wrap text directly in a list with a list item', () => {
  const original = [
    Model.p(),
    {
      ...Model.ul(),
      children: [{ text: 'Hello World' }],
    },
    Model.p(),
  ];
  const { editor } = runNormalizer(original);
  expect(editor.children).toEqual(
    expectAnyId([
      expectAnyEmptyParagraph,
      Model.ul([Model.li([Model.p('Hello World')])]),
      expectAnyEmptyParagraph,
    ]),
  );
});
