import React from 'react';
import { updateModel, getEditMode } from 'components/editing/models/utils';
import * as Settings from 'components/editing/models/settings/Settings';
import { CodeLanguages } from 'data/content/model/other';
export const CodeEditor = (props) => {
    const { model, editor } = props;
    const editMode = getEditMode(editor);
    const updateProperty = (value, key) => onEdit(Object.assign({}, model, { [key]: value }));
    const onEdit = (updated) => {
        updateModel(editor, model, updated);
    };
    return (<React.Fragment>
      <div {...props.attributes} className="code-editor">
        <div contentEditable={false} style={{ userSelect: 'none', display: 'flex', justifyContent: 'space-between' }}>
          <Settings.Select value={model.language} onChange={(value) => updateProperty(value, 'language')} editor={editor} options={Object.keys(CodeLanguages)
            .filter((k) => typeof CodeLanguages[k] === 'number')
            .sort()}/>
        </div>
        <div className="code-editor-content">
          <pre style={{ fontFamily: 'Menlo, Monaco, Courier New, monospace' }}>
            <code className={`language-${model.language}`}>{props.children}</code>
          </pre>
        </div>
      </div>

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <Settings.Input editMode={editMode} value={model.caption} onChange={(value) => updateProperty(value, 'caption')} editor={editor} model={model} placeholder="Set a caption for this code block"/>
      </div>
    </React.Fragment>);
};
export const CodeBlockLine = (props) => {
    return <div {...props.attributes}>{props.children}</div>;
};
//# sourceMappingURL=Editor.jsx.map