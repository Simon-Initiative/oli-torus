import Delta from 'quill-delta';
import React, { useEffect } from 'react';
import ReactQuill, { Quill } from 'react-quill';
import register from '../customElementWrapper';
import { convertJanusToQuill, convertQuillToJanus } from './quill-utils';

interface QuillEditorProps {
  tree: any[];
  html?: string;
  onChange: (changes: any) => void;
  onSave: (contents: any) => void;
  onCancel: () => void;
  showSaveCancelButtons?: boolean;
  showimagecontrol?: boolean;
}

const supportedFonts = ['Initial', 'Arial', 'Times New Roman', 'Sans Serif'];

// get code friendly font names
const getFontName = (font: string) => {
  return font.toLowerCase().replace(/\s/g, '-');
};

const FontAttributor = Quill.import('attributors/class/font');
FontAttributor.whitelist = supportedFonts.map(getFontName);
Quill.register(FontAttributor, true);

const FontSizeAttributor = Quill.import('attributors/style/size');
FontSizeAttributor.whitelist = ['10px', '12px', '14px', '16px', '18px'];
Quill.register(FontSizeAttributor, true);

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

const fontStyles = `${getCssForFonts(supportedFonts)}
/* default normal size */
.ql-container {
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="10px"]::before {
  content: 'Smaller (10px)';
  font-size: 10px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="12px"]::before {
  content: 'Small (12px)';
  font-size: 12px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="14px"]::before {
  content: 'Normal (14px)';
  font-size: 14px !important;
}

.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="16px"]::before {
  content: 'Large (16px)';
  font-size: 16px !important;
}

.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="18px"]::before {
  content: 'Larger (18px)';
  font-size: 18px !important;
}
`;

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
  image: function (value: string) {
    const range = this.quill.getSelection();
    const expression = prompt('Enter the image URL', '');
    if (expression) {
      this.quill.insertEmbed(range.index, 'image', expression);
    }
  },
};

export const QuillEditor: React.FC<QuillEditorProps> = ({
  tree,
  html,
  showSaveCancelButtons = false,
  onChange,
  onSave,
  onCancel,
  showimagecontrol = false,
}) => {
  const [contents, setContents] = React.useState<any>(tree);
  const [delta, setDelta] = React.useState<any>(convertJanusToQuill(tree));

  /*  console.log('[QuillEditor]', { tree, html }); */

  useEffect(() => {
    const convertedTree = convertJanusToQuill(tree);
    /* console.log('[QuillEditor] convertedTree', convertedTree); */
    setDelta(convertedTree);
  }, [tree]);

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
                [
                  { font: FontAttributor.whitelist },
                  { size: ['10px', '12px', '14px', '16px', '18px'] },
                ],
                [{ align: [] }],
                ['link', 'adaptivity'],
                ['clean'], // remove formatting button
                showimagecontrol ? ['image'] : [],
              ],
              handlers: customHandlers,
            },
          }}
          defaultValue={delta}
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
    register(QuillEditor, tagName, ['tree', 'html', 'showimagecontrol'], {
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
