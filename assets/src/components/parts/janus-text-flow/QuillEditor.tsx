import Delta from 'quill-delta';
import React from 'react';
import ReactQuill, { Quill } from 'react-quill';
import register from '../customElementWrapper';
import { convertQuillToJanus } from './quill-utils';

interface QuillEditorProps {
  tree: any[];
  html?: string;
  onChange: (changes: any) => void;
  onSave: (contents: any) => void;
  onCancel: () => void;
  showSaveCancelButtons?: boolean;
}

const supportedFonts = ['Initial', 'Arial', 'Times New Roman', 'Sans Serif'];

// get code friendly font names
const getFontName = (font: string) => {
  return font.toLowerCase().replace(/\s/g, '-');
};

const FontAttributor = Quill.import('attributors/class/font');
FontAttributor.whitelist = supportedFonts.map(getFontName);
Quill.register(FontAttributor, true);

const getCssForFonts = (fonts: string[]) => {
  return fonts
    .map(
      (font) => `
    .ql-snow .ql-picker.ql-font .ql-picker-label[data-value='${getFontName(font)}']::before,
    .ql-snow .ql-picker.ql-font .ql-picker-item[data-value='${getFontName(font)}']::before
    {
      content: '${font}';
      font-family: '${font}';
    }
    .ql-font-${getFontName(font)} {
      font-family: '${font}';
    }
  `,
    )
    .join('\n');
};

const fontStyles = getCssForFonts(supportedFonts);

const customHandlers = {
  adaptivity: function (value: string) {
    const range = this.quill.getSelection();
    let selectionValue = '';
    if (range && range.length > 0) {
      selectionValue = this.quill.getText(range.index, range.length);
      if (selectionValue.charAt(0) === '{') {
        selectionValue = selectionValue.substring(1, selectionValue.length - 1);
      }
    }
    const expression = prompt('Enter the Expression', selectionValue);
    if (expression) {
      this.quill.insertText(range.index, `{${expression}}`);
      this.quill.deleteText(range.index + expression.length + 2, expression.length + 2);
    }
  },
};

const QuillEditor: React.FC<QuillEditorProps> = ({
  tree,
  html,
  showSaveCancelButtons = false,
  onChange,
  onSave,
  onCancel,
}) => {
  const [contents, setContents] = React.useState<any>(tree);

  // console.log('[QuillEditor]', { tree, html });

  const handleSave = React.useCallback(() => {
    if (!contents) {
      return;
    }
    onSave(contents);
  }, [onSave, contents]);

  const handleQuillChange = React.useCallback(
    (content, delta, source, editor) => {
      // console.log('quill changes', { content, delta, source, editor });
      const janusText = convertQuillToJanus(new Delta(editor.getContents().ops));
      // console.log('JANUS TEXT', janusText);
      setContents(janusText);
      onChange({ value: janusText });
    },
    [onChange],
  );

  return (
    <React.Fragment>
      <link rel="stylesheet" href="https://cdn.quilljs.com/1.3.6/quill.snow.css" />
      <style>{fontStyles}</style>
      <div
        style={{
          maxWidth: 520,
          height: '100%',
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          backgroundColor: '#fff',
        }}
      >
        <ReactQuill
          style={{ maxHeight: '100%' }}
          modules={{
            toolbar: {
              container: [
                ['bold', 'italic', 'underline', 'strike'], // toggled buttons
                ['blockquote' /* , 'code-block' */],

                [{ list: 'ordered' }, { list: 'bullet' }],
                [{ script: 'sub' }, { script: 'super' }], // superscript/subscript
                [{ indent: '-1' }, { indent: '+1' }], // outdent/indent

                [{ header: [1, 2, 3, 4, 5, 6, false] }],

                [{ color: [] }, { background: [] }], // dropdown with defaults from theme
                [{ font: FontAttributor.whitelist }],
                [{ align: [] }],

                ['link', 'adaptivity'],

                ['clean'], // remove formatting button
              ],
              handlers: customHandlers,
            },
          }}
          defaultValue={html}
          onChange={handleQuillChange}
        />
        {showSaveCancelButtons && (
          <>
            <button onClick={handleSave}>Save</button>
            <button onClick={onCancel}>Cancel</button>
          </>
        )}
      </div>
    </React.Fragment>
  );
};

export const tagName = 'tf-quill-editor';

export const registerEditor = () => {
  if (!customElements.get(tagName)) {
    register(QuillEditor, tagName, ['tree', 'html'], {
      shadow: false, // shadow dom breaks the quill toolbar
      customEvents: {
        onChange: `${tagName}-change`,
        onSave: `${tagName}-save`,
        onCancel: `${tagName}-cancel`,
      },
      attrs: {
        tree: {
          json: true,
        },
      },
    });
  }
};
