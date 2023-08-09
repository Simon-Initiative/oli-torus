import { Editor } from 'slate';
import { reparentNestedTables } from 'components/editing/editor/paste/onHtmlPaste';
import { onHTMLPaste } from 'components/editing/editor/paste/onHtmlPaste';
import { mockEditor, mockInsertFragment, simulateEvent } from './paste_test_utils';

const html = (fragment: string) => `<html><body>${fragment}</body></html>`;

// Note: Most of the style-based pasting we use for MSWord works here too, so we don't need to test them all in both places.
describe('on OLI Echo output paste', () => {
  let editor: Editor;
  let insertFragmentSpy: jest.SpyInstance;

  beforeEach(() => {
    editor = mockEditor();
    insertFragmentSpy = mockInsertFragment();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should paste terms', () => {
    const event = simulateEvent('', html(`<span class="term">term</span>`));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [{ text: 'term', term: true }]);
  });

  it('should paste strikethrough', () => {
    const event = simulateEvent('', html(`<em class="line-through">strikethrough</span>`));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      { text: 'strikethrough', strikethrough: true },
    ]);
  });
  /*
    If you insert a table in Echo, you actually get a table inside a table.
    The outter table is for the title, table, and caption.
    The inner table is the actual table.

    Torus can not handle nested tables, so we we reparent any nested tables as siblings of each other.

    There's not a great way of checking if it's a paste from echo, so I didn't try to fill in
    the caption or title.  It'll look a little weird, but at least no data is lost.
  */
  describe('reparentNestedTables', () => {
    it('should reparent nested tables', () => {
      const input: any[] = [
        {
          type: 'table',
          id: 'outter-table',
          children: [
            {
              type: 'tr',
              children: [
                { type: 'td', children: [{ type: 'table', id: 'inner-table', children: [] }] },
                { type: 'td', children: [{ text: 'b' }] },
              ],
            },
            {
              type: 'tr',
              children: [
                { type: 'td', children: [{ text: 'c' }] },
                { type: 'td', children: [{ text: 'd' }] },
              ],
            },
          ],
        },
      ];
      const output = reparentNestedTables(input);
      expect(output).toEqual([
        {
          type: 'table',
          id: 'outter-table',
          children: expect.any(Array),
        },
        {
          type: 'table',
          id: 'inner-table',
          children: expect.any(Array),
        },
      ]);

      // Make sure the innter table was removed from the outter table
      const innerTableTD = (output[0] as any).children[0].children[0];
      expect(innerTableTD.children.length).toEqual(0);
    });
  });
});
