import Delta from 'quill-delta';
import React from 'react';
import ReactQuill from 'react-quill';
import register from '../customElementWrapper';
import { convertJanusToQuill, convertQuillToJanus } from './quill-utils';

interface QuillEditorProps {
  tree: any[];
  onChange: (changes: any) => void;
  onSave: (contents: any) => void;
  onCancel: () => void;
}

const QuillEditor: React.FC<QuillEditorProps> = ({ tree, onChange, onSave, onCancel }) => {
  const [contents, setContents] = React.useState<any>(tree);

  const handleSave = React.useCallback(() => {
    onSave(contents);
  }, [onSave, contents]);

  return (
    <React.Fragment>
      <link rel="stylesheet" href="https://cdn.quilljs.com/1.3.6/quill.snow.css" />
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
            toolbar: [
              ['bold', 'italic', 'underline', 'strike'], // toggled buttons
              ['blockquote', 'code-block'],

              [{ header: 1 }, { header: 2 }], // custom button values
              [{ list: 'ordered' }, { list: 'bullet' }],
              [{ script: 'sub' }, { script: 'super' }], // superscript/subscript
              [{ indent: '-1' }, { indent: '+1' }], // outdent/indent
              [{ direction: 'rtl' }], // text direction

              [{ size: ['small', false, 'large', 'huge'] }], // custom dropdown
              [{ header: [1, 2, 3, 4, 5, 6, false] }],

              [{ color: [] }, { background: [] }], // dropdown with defaults from theme
              [{ font: [] }],
              [{ align: [] }],

              ['clean'], // remove formatting button
            ],
          }}
          defaultValue={convertJanusToQuill(tree) as any}
          onChange={(content, delta, source, editor) => {
            console.log('quill changes', { content, delta, source, editor });
            const janusText = convertQuillToJanus(new Delta(editor.getContents().ops));
            console.log('JANUS TEXT', janusText);
            setContents(janusText);
            onChange({ value: janusText });
          }}
        />
        <button onClick={handleSave}>Save</button>
        <button onClick={onCancel}>Cancel</button>
      </div>
    </React.Fragment>
  );
};

export const tagName = 'tf-quill-editor';

export const registerEditor = () => {
  if (!customElements.get(tagName)) {
    register(QuillEditor, tagName, ['tree'], {
      shadow: true,
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
