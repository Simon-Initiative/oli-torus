import { Editor } from 'slate';
import { onHTMLPaste } from 'components/editing/editor/paste/onHtmlPaste';
import { mockEditor, mockInsertFragment, simulateEvent } from './paste_test_utils';

const html = (fragment: string) => `<html><body>${fragment}</body></html>`;

// Note: Most of the style-based pasting we use for MSWord works here too, so we don't need to test them all in both places.

describe('on Google Docs paste', () => {
  let editor: Editor;
  let insertFragmentSpy: jest.SpyInstance;

  beforeEach(() => {
    editor = mockEditor();
    insertFragmentSpy = mockInsertFragment();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should ignore google doc extra bold tags', () => {
    // Example of the markup that Word generates for bold text:
    const event = simulateEvent('', html(`<b style="font-weight: normal;">Normal Text</b>`));
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [{ text: 'Normal Text' }]);
  });

  it('should import a google docs ordered list', () => {
    const event = simulateEvent(
      '',
      html(`<ol style="margin-top: 0; margin-bottom: 0; padding-inline-start: 48px">
      <li
        dir="ltr"
        style="
          list-style-type: decimal;
          font-size: 11pt;
          font-family: Arial, sans-serif;
          color: #000000;
          background-color: transparent;
          font-weight: 400;
          font-style: normal;
          font-variant: normal;
          text-decoration: none;
          vertical-align: baseline;
          white-space: pre;
        "
        aria-level="1"
      >
        <p
          dir="ltr"
          style="line-height: 1.38; margin-top: 0pt; margin-bottom: 0pt"
          role="presentation"
        ><span
            style="
              font-size: 11pt;
              font-family: Arial, sans-serif;
              color: #000000;
              background-color: transparent;
              font-weight: 400;
              font-style: normal;
              font-variant: normal;
              text-decoration: none;
              vertical-align: baseline;
              white-space: pre;
              white-space: pre-wrap;
            "
            >Here is a numbered list</span
          ></p>
      </li>
      <li
        dir="ltr"
        style="
          list-style-type: decimal;
          font-size: 11pt;
          font-family: Arial, sans-serif;
          color: #000000;
          background-color: transparent;
          font-weight: 400;
          font-style: normal;
          font-variant: normal;
          text-decoration: none;
          vertical-align: baseline;
          white-space: pre;
        "
        aria-level="1"
      >
        <p
          dir="ltr"
          style="line-height: 1.38; margin-top: 0pt; margin-bottom: 0pt"
          role="presentation"
        ><span
            style="
              font-size: 11pt;
              font-family: Arial, sans-serif;
              color: #000000;
              background-color: transparent;
              font-weight: 400;
              font-style: normal;
              font-variant: normal;
              text-decoration: none;
              vertical-align: baseline;
              white-space: pre;
              white-space: pre-wrap;
            "
            >With three</span
          ></p>
      </li>
      <li
        dir="ltr"
        style="
          list-style-type: decimal;
          font-size: 11pt;
          font-family: Arial, sans-serif;
          color: #000000;
          background-color: transparent;
          font-weight: 400;
          font-style: normal;
          font-variant: normal;
          text-decoration: none;
          vertical-align: baseline;
          white-space: pre;
        "
        aria-level="1"
      >
        <p
          dir="ltr"
          style="line-height: 1.38; margin-top: 0pt; margin-bottom: 0pt"
          role="presentation"
        ><span
            style="
              font-size: 11pt;
              font-family: Arial, sans-serif;
              color: #000000;
              background-color: transparent;
              font-weight: 400;
              font-style: normal;
              font-variant: normal;
              text-decoration: none;
              vertical-align: baseline;
              white-space: pre;
              white-space: pre-wrap;
            "
            >Items in it</span
          ></p>
      </li>
    </ol>`),
    );
    onHTMLPaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalledTimes(1);
    expect(insertFragmentSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'ol',
        id: expect.any(String),
        children: [
          {
            type: 'li',
            id: expect.any(String),
            children: [
              {
                type: 'p',
                id: expect.any(String),
                children: [{ text: 'Here is a numbered list' }],
              },
            ],
          },
          {
            type: 'li',
            id: expect.any(String),
            children: [{ type: 'p', id: expect.any(String), children: [{ text: 'With three' }] }],
          },
          {
            type: 'li',
            id: expect.any(String),
            children: [{ type: 'p', id: expect.any(String), children: [{ text: 'Items in it' }] }],
          },
        ],
      },
    ]);
  });
});
