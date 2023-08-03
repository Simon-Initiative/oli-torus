import { Editor, createEditor } from 'slate';
import { withHistory } from 'slate-history';
import { withReact } from 'slate-react';
import { installNormalizer } from 'components/editing/editor/normalizers/normalizer';
import { withInlines } from 'components/editing/editor/overrides/inlines';
import { withTables } from 'components/editing/editor/overrides/tables';
import { withVoids } from 'components/editing/editor/overrides/voids';
import { Model } from 'data/content/model/elements/factories';

const expectAnyEmptyParagraph = { type: 'p', id: expect.any(String), children: [{ text: '' }] };

describe('List normalization', () => {
  it('should not touch non-lists', () => {
    const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));
    const original = Model.p('Hello World');
    editor.children = [original];
    installNormalizer(editor);
    Editor.normalize(editor, { force: true });
    expect(editor.children).toEqual([original]);
  });

  it('should not touch well formed lists', () => {
    const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));
    const original = [
      Model.p('Hello World'),
      Model.ul([Model.li('Hello List World 1'), Model.li('Hello list World 2')]),
      Model.p('Goodbye World'),
    ];
    editor.children = [...original];
    installNormalizer(editor);
    Editor.normalize(editor, { force: true });
    expect(editor.children).toEqual(original);
  });

  it('should wrap text nodes inside list items with a p', () => {
    const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));
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
    editor.children = [...original];
    installNormalizer(editor);
    Editor.normalize(editor, { force: true });
    jest.clearAllMocks();

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
              children: [{ text: 'Hello World' }],
            },
          ],
        },
      ],
    });
  });

  it('should wrap multiple text nodes inside list items with a single p', () => {
    const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));
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
    editor.children = [...original];
    installNormalizer(editor);
    Editor.normalize(editor, { force: true });

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
              children: [{ text: 'Hello World 1 Hello World 2' }],
              // Note: Slate also combines adjacent text nodes with the same marks
            },
          ],
        },
      ],
    });
  });

  it('should wrap multiple text nodes with different marks inside list items with a single p', () => {
    const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));
    const original = [
      Model.p(''),
      Model.ul([
        {
          ...Model.li(),
          children: [
            { text: 'Hello World 1', bold: true } as any,
            { text: 'Hello World 2', italic: true } as any,
          ],
        },
      ]),
      Model.p(''),
    ];
    editor.children = [...original];
    installNormalizer(editor);
    Editor.normalize(editor, { force: true });

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
              children: [
                { text: 'Hello World 1', bold: true },
                { text: 'Hello World 2', italic: true },
              ],
            },
          ],
        },
      ],
    });
  });

  it('removes mixed block and inline children in list items', () => {
    const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));
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
    editor.children = [...original];
    installNormalizer(editor);
    Editor.normalize(editor, { force: true });

    expect(editor.children).toEqual([
      expectAnyEmptyParagraph,
      {
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
                children: [{ text: 'Hello World 1' }],
              },
            ],
          },
        ],
      },
      expectAnyEmptyParagraph,
    ]);
  });

  it('preserves a popup in a list item', () => {
    // Simulates MER-2448
    const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));

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
    editor.children = [...original];
    installNormalizer(editor);
    Editor.normalize(editor, { force: true });

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
});
