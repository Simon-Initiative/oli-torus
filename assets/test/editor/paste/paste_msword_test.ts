import { Editor } from 'slate';
import { onHTMLPaste } from 'components/editing/editor/paste/onHtmlPaste';
import { mswordListExample } from './mswordListExample';
import { msWordTableExample } from './mswordTableExample';
import { mockEditor, mockInsertFragment, simulateEvent } from './paste_test_utils';

const html = (fragment: string) => `<html><body>${fragment}</body></html>`;

describe('on MSWord paste', () => {
  let editor: Editor;
  let insertFragmentSpy: jest.SpyInstance;

  beforeEach(() => {
    editor = mockEditor();
    insertFragmentSpy = mockInsertFragment();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should set ms-word style bold', () => {
    // Example of the markup that Word generates for bold text:
    const event = simulateEvent(
      '',
      html(`<span data-contrast="auto" xml:lang="EN-US" lang="EN-US" class="TextRun SCXW221903159 BCX0" style="
          margin: 0px;
          padding: 0px;
          user-select: text;
          -webkit-user-drag: none;
          -webkit-tap-highlight-color: transparent;
          font-variant-ligatures: none !important;
          font-size: 11pt;
          line-height: 19.425px;
          font-family: Calibri, Calibri_EmbeddedFont, Calibri_MSFontService,
            sans-serif;
          font-weight: bold;
        "
        ><span class="NormalTextRun SCXW221903159 BCX0" style="
            margin: 0px;
            padding: 0px;
            user-select: text;
            -webkit-user-drag: none;
            -webkit-tap-highlight-color: transparent;
          "
          >bold</span></span>`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [{ text: 'bold', strong: true }]);
  });

  it('should set ms-word style italic', () => {
    // Example of the markup that Word generates for bold text:
    const event = simulateEvent(
      '',
      html(`<span data-contrast="auto" xml:lang="EN-US" lang="EN-US" class="TextRun SCXW221903159 BCX0" style="
        margin: 0px;
        padding: 0px;
        user-select: text;
        -webkit-user-drag: none;
        -webkit-tap-highlight-color: transparent;
        font-variant-ligatures: none !important;
        font-size: 11pt;
        font-style: italic;
        line-height: 19.425px;
        font-family: Calibri, Calibri_EmbeddedFont, Calibri_MSFontService,
          sans-serif;
      "
      ><span class="NormalTextRun SCXW221903159 BCX0" style="
          margin: 0px;
          padding: 0px;
          user-select: text;
          -webkit-user-drag: none;
          -webkit-tap-highlight-color: transparent;
        "
        >italic</span></span>`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [{ text: 'italic', em: true }]);
  });

  it('should set ms-word style underline', () => {
    // Example of the markup that Word generates for bold text:
    const event = simulateEvent(
      '',
      html(`<span data-contrast="auto" xml:lang="EN-US" lang="EN-US" class="TextRun Underlined SCXW221903159 BCX0" style="
        margin: 0px;
        padding: 0px;
        user-select: text;
        -webkit-user-drag: none;
        -webkit-tap-highlight-color: transparent;
        font-variant-ligatures: none !important;
        font-size: 11pt;
        text-decoration: underline;
        line-height: 19.425px;
        font-family: Calibri, Calibri_EmbeddedFont, Calibri_MSFontService,
          sans-serif;
      "
      ><span class="NormalTextRun ContextualSpellingAndGrammarErrorV2Themed SCXW221903159 BCX0" style="
          margin: 0px;
          padding: 0px;
          user-select: text;
          -webkit-user-drag: none;
          -webkit-tap-highlight-color: transparent;
          background-repeat: repeat-x;
          background-position: left bottom;
          border-bottom: 1px solid transparent;
        "
        >underline</span
      ></span>`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      { text: 'underline', underline: true },
    ]);
  });

  it('should set ms-word style underline', () => {
    // Example of the markup that Word generates for bold text:
    const event = simulateEvent(
      '',
      html(`<span data-contrast="auto" xml:lang="EN-US" lang="EN-US" class="TextRun Strikethrough SCXW221903159 BCX0" style="
        margin: 0px;
        padding: 0px;
        user-select: text;
        -webkit-user-drag: none;
        -webkit-tap-highlight-color: transparent;
        font-variant-ligatures: none !important;
        font-size: 11pt;
        text-decoration: line-through;
        line-height: 19.425px;
        font-family: Calibri, Calibri_EmbeddedFont, Calibri_MSFontService,
          sans-serif;
      "
      ><span class="NormalTextRun SCXW221903159 BCX0" style="
          margin: 0px;
          padding: 0px;
          user-select: text;
          -webkit-user-drag: none;
          -webkit-tap-highlight-color: transparent;
        "
        >strikethrough</span
      ></span
    >`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      { text: 'strikethrough', strikethrough: true },
    ]);
  });

  it('should set ms-word style heading', () => {
    const event = simulateEvent(
      '',
      html(`<p
      class="Paragraph SCXW221903159 BCX0"
      role="heading"
      aria-level="1"
      paraid="738692707"
      paraeid="{f525c0e0-dcf0-4a2b-badc-2a45532affdf}{161}"
      style="
        margin: 0px;
        padding: 0px;
        user-select: text;
        -webkit-user-drag: none;
        -webkit-tap-highlight-color: transparent;
        overflow-wrap: break-word;
        white-space: pre-wrap;
        font-weight: normal;
        font-style: normal;
        vertical-align: baseline;
        font-kerning: none;
        background-color: transparent;
        color: rgb(47, 84, 150);
        text-align: left;
        text-indent: 0px;
      "
    ><span data-contrast="none" xml:lang="EN-US" lang="EN-US" class="TextRun SCXW221903159 BCX0" style="
        margin: 0px;
        padding: 0px;
        user-select: text;
        -webkit-user-drag: none;
        -webkit-tap-highlight-color: transparent;
        font-variant-ligatures: none !important;
        color: rgb(47, 84, 150);
        font-size: 16pt;
        line-height: 28.0583px;
        font-family: 'Calibri Light', 'Calibri Light_EmbeddedFont',
          'Calibri Light_MSFontService', sans-serif;
      "
      ><span class="NormalTextRun SCXW221903159 BCX0" data-ccp-parastyle="heading 1" style="
          margin: 0px;
          padding: 0px;
          user-select: text;
          -webkit-user-drag: none;
          -webkit-tap-highlight-color: transparent;
        "
        >This is heading text</span></span></p>`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      { type: 'h1', id: expect.any(String), children: [{ text: 'This is heading text' }] },
    ]);
  });

  it('should set ms-word style subscript', () => {
    const event = simulateEvent(
      '',
      html(`<span data-contrast="auto" xml:lang="EN-US" lang="EN-US" class="TextRun SCXW216742723 BCX0" style="
        margin: 0px;
        padding: 0px;
        user-select: text;
        -webkit-user-drag: none;
        -webkit-tap-highlight-color: transparent;
        font-variant-ligatures: none !important;
        font-size: 8.5pt;
        line-height: 19.425px;
        font-family: Calibri, Calibri_EmbeddedFont, Calibri_MSFontService,
          sans-serif;
      "
      ><span class="NormalTextRun Subscript SCXW216742723 BCX0" data-fontsize="11" style="
          margin: 0px;
          padding: 0px;
          user-select: text;
          -webkit-user-drag: none;
          -webkit-tap-highlight-color: transparent;
          vertical-align: sub;
        "
        >subscript</span
      ></span>`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [{ text: 'subscript', sub: true }]);
  });

  it('should set ms-word style superscript', () => {
    const event = simulateEvent(
      '',
      html(`<span data-contrast="auto" xml:lang="EN-US" lang="EN-US" class="TextRun SCXW216742723 BCX0" style="
        margin: 0px;
        padding: 0px;
        user-select: text;
        -webkit-user-drag: none;
        -webkit-tap-highlight-color: transparent;
        font-variant-ligatures: none !important;
        font-size: 8.5pt;
        line-height: 19.425px;
        font-family: Calibri, Calibri_EmbeddedFont, Calibri_MSFontService,
          sans-serif;
      "
      ><span class="NormalTextRun Subscript SCXW216742723 BCX0" data-fontsize="11" style="
          margin: 0px;
          padding: 0px;
          user-select: text;
          -webkit-user-drag: none;
          -webkit-tap-highlight-color: transparent;
          vertical-align: super;
        "
        >superscript</span
      ></span>`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [{ text: 'superscript', sup: true }]);
  });

  it('should paste an ms-word table with colspan and rowspans set', () => {
    const event = simulateEvent('', html(msWordTableExample));
    onHTMLPaste(event, editor);

    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'table',
        id: expect.any(String),
        children: [
          {
            type: 'tr',
            id: expect.any(String),
            children: [
              {
                type: 'td',
                id: expect.any(String),
                colspan: 2,
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: 'Merged cell on the left.',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
              {
                type: 'td',
                id: expect.any(String),
                colspan: 2,
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: 'Merged cell on the right',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
            ],
          },
          {
            type: 'tr',
            id: expect.any(String),
            children: [
              {
                type: 'td',
                id: expect.any(String),
                colspan: 1,
                rowspan: 2,
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: 'Vertically merged cell',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
              {
                type: 'td',
                id: expect.any(String),
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: '',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
              {
                type: 'td',
                id: expect.any(String),
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: '',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
              {
                type: 'td',
                id: expect.any(String),
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: '',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
            ],
          },
          {
            type: 'tr',
            id: expect.any(String),
            children: [
              {
                type: 'td',
                id: expect.any(String),
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: '',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
              {
                type: 'td',
                id: expect.any(String),
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: '',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
              {
                type: 'td',
                id: expect.any(String),
                children: [
                  {
                    type: 'p',
                    id: expect.any(String),
                    children: [
                      {
                        text: '',
                      },
                      {
                        text: ' ',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    ]);
  });

  it('should string multiple msword ordered lists together', () => {
    const event = simulateEvent('', html(mswordListExample));
    onHTMLPaste(event, editor);
    console.info(JSON.stringify(insertFragmentSpy.mock.calls[0][1], null, 2));
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      expect.any(Object),
      {
        type: 'ol',
        id: expect.any(String),
        start: '1',
        children: [
          {
            type: 'li',
            id: expect.any(String),
            children: [
              {
                type: 'p',
                id: expect.any(String),
                children: [
                  {
                    text: 'Here is a numbered list',
                  },
                  {
                    text: ' ',
                  },
                ],
              },
            ],
          },
          {
            type: 'li',
            id: expect.any(String),
            children: [
              {
                type: 'p',
                id: expect.any(String),
                children: [
                  {
                    text: 'With three items',
                  },
                  {
                    text: ' ',
                  },
                ],
              },
            ],
          },
          {
            type: 'li',
            id: expect.any(String),
            children: [
              {
                type: 'p',
                id: expect.any(String),
                children: [
                  {
                    text: 'In it',
                  },
                  {
                    text: ' ',
                  },
                ],
              },
            ],
          },
        ],
      },

      expect.any(Object),
    ]);
  });
});
