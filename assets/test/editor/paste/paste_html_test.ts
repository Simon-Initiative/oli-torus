import { Editor } from 'slate';
import { onHTMLPaste } from 'components/editing/editor/paste/onHtmlPaste';
import { mockEditor, mockInsertFragment, simulateEvent } from './paste_test_utils';

const html = (fragment: string) => `<html><body>${fragment}</body></html>`;

describe('onHTMLPaste', () => {
  let editor: Editor;
  let insertFragmentSpy: jest.SpyInstance;

  beforeEach(() => {
    editor = mockEditor();
    insertFragmentSpy = mockInsertFragment();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should not do anything if no text is pasted', () => {
    const event = simulateEvent('', '');
    onHTMLPaste(event, editor);
    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(insertFragmentSpy).not.toHaveBeenCalled();
  });

  it('should not do anything if plain text is pasted', () => {
    const event = simulateEvent('This is my paste text', '');
    onHTMLPaste(event, editor);
    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(insertFragmentSpy).not.toHaveBeenCalled();
  });

  it('should paste in paragraphs', () => {
    const event = simulateEvent(
      '',
      html('<p>This is my paste text</p><p>And this is another paragraph</p>'),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [{ text: 'This is my paste text' }],
        id: expect.any(String),
      },
      {
        type: 'p',
        children: [{ text: 'And this is another paragraph' }],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste in bold text', () => {
    const event = simulateEvent('', html('<p>one <b>two</b> three</p>'));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [{ text: 'one ' }, { text: 'two', strong: true }, { text: ' three' }],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste in bold text from a style', () => {
    const event = simulateEvent(
      '',
      html('<p>one <span style="font-weight: bold;">two</span> three</p>'),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [{ text: 'one ' }, { text: 'two', strong: true }, { text: ' three' }],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste in italic text', () => {
    const event = simulateEvent('', html('<p>one <i>two</i> three</p>'));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [{ text: 'one ' }, { text: 'two', em: true }, { text: ' three' }],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste in inline code', () => {
    const event = simulateEvent('', html('<p>one <code>two</code> three</p>'));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [{ text: 'one ' }, { text: 'two', code: true }, { text: ' three' }],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste a variety of formatting marks', () => {
    const event = simulateEvent(
      '',
      html(
        `<p>Plain<u>Underline</u><del>strikethrough</del><sub>subscript</sub><sub><sub>double subscript</sub></sub><sup>superscript</sup><small>deemphasis</small>`,
      ),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalled();

    const args = insertFragmentSpy.mock.calls[0][1];
    const [p1] = args;
    const { children } = p1;
    expect(children.length).toEqual(7);

    expect(children[0]).toEqual({ text: 'Plain' });
    expect(children[1]).toEqual({ text: 'Underline', underline: true });
    expect(children[2]).toEqual({ text: 'strikethrough', strikethrough: true });
    expect(children[3]).toEqual({ text: 'subscript', sub: true });
    expect(children[4]).toEqual({ text: 'double subscript', doublesub: true });
    expect(children[5]).toEqual({ text: 'superscript', sup: true });
    expect(children[6]).toEqual({ text: 'deemphasis', deemphasis: true });
  });

  it('should not sub and double sub at the same time', () => {
    const event = simulateEvent('', html('<p><sub><sub><sub>Tripple Sub</sub></sub></sub></p>'));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [{ text: 'Tripple Sub', doublesub: true }],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste foreign language tags', () => {
    const event = simulateEvent('', html('<p><i lang="fr">french</i></p>'));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [
          { type: 'foreign', lang: 'fr', children: [{ text: 'french' }], id: expect.any(String) },
        ],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste headings h1-h6', () => {
    const event = simulateEvent(
      '',
      html('<h1>h1</h1><h2>h2</h2><h3>h3</h3><h4>h4</h4><h5>h5</h5><h6>h6</h6>'),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      { type: 'h1', children: [{ text: 'h1' }], id: expect.any(String) },
      { type: 'h2', children: [{ text: 'h2' }], id: expect.any(String) },
      { type: 'h3', children: [{ text: 'h3' }], id: expect.any(String) },
      { type: 'h4', children: [{ text: 'h4' }], id: expect.any(String) },
      { type: 'h5', children: [{ text: 'h5' }], id: expect.any(String) },
      { type: 'h6', children: [{ text: 'h6' }], id: expect.any(String) },
    ]);
  });

  it('should paste links', () => {
    const event = simulateEvent('', html('<p><a href="https://example.com">Example</a></p>'));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'p',
        children: [
          {
            type: 'a',
            href: 'https://example.com',
            children: [{ text: 'Example' }],
            id: expect.any(String),
          },
        ],
        id: expect.any(String),
      },
    ]);
  });

  it('should paste block code', () => {
    const event = simulateEvent(
      '',
      html('<pre data-language="java">public class Example {}</pre>'),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'code',
        language: 'java',
        children: [{ text: '' }],
        code: 'public class Example {}',
        id: expect.any(String),
      },
    ]);
  });

  it('should paste an unordered list', () => {
    const event = simulateEvent('', html('<ul><li>One</li><li>Two</li><li>Three</li></ul>'));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'ul',
        id: expect.any(String),
        children: [
          { type: 'li', id: expect.any(String), children: [{ text: 'One' }] },
          { type: 'li', id: expect.any(String), children: [{ text: 'Two' }] },
          { type: 'li', id: expect.any(String), children: [{ text: 'Three' }] },
        ],
      },
    ]);
  });

  it('should paste a table', () => {
    const event = simulateEvent(
      '',
      html(
        `<table>
          <tr><th>Header 1</th><th>Header 2</th></tr>
          <tr><td>1</td><td>2</td></tr>
          <tr><td>3</td><td>4</td></tr>
        </table>`,
      ),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'table',
        id: expect.any(String),
        children: [
          {
            type: 'tr',
            id: expect.any(String),
            children: [
              { type: 'th', id: expect.any(String), children: [{ text: 'Header 1' }] },
              { type: 'th', id: expect.any(String), children: [{ text: 'Header 2' }] },
            ],
          },

          {
            type: 'tr',
            id: expect.any(String),
            children: [
              { type: 'td', id: expect.any(String), children: [{ text: '1' }] },
              { type: 'td', id: expect.any(String), children: [{ text: '2' }] },
            ],
          },
          {
            type: 'tr',
            id: expect.any(String),
            children: [
              { type: 'td', id: expect.any(String), children: [{ text: '3' }] },
              { type: 'td', id: expect.any(String), children: [{ text: '4' }] },
            ],
          },
        ],
      },
    ]);
  });
});
