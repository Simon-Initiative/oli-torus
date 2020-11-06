import React from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editing/models/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import * as Settings from 'components/editing/models/settings/Settings';

export interface CodeProps extends EditorProps<ContentModel.Code> { }

export const CodeEditor = (props: CodeProps) => {

  const { model, editor } = props;

  const editMode = getEditMode(editor);

  const updateProperty = (value: string, key: string) =>
    onEdit(Object.assign({}, model, { [key]: value }));

  const onEdit = (updated: ContentModel.Code) => {
    updateModel<ContentModel.Code>(editor, model, updated);
  };

  return (
    <React.Fragment>
      <div {...props.attributes} className="code-editor">
        <div
          contentEditable={false}
          style={{ userSelect: 'none', display: 'flex', justifyContent: 'space-between' }}>
          <Settings.Select
            value={model.language}
            onChange={value => updateProperty(value, 'language')}
            editor={editor}
            options={Object
              .keys(ContentModel.CodeLanguages)
              .filter(k => typeof ContentModel.CodeLanguages[k as any] === 'number')
              .sort()}
          />
        </div>
        <div className="code-editor-content">
          <pre style={{ fontFamily: 'Menlo, Monaco, Courier New, monospace' }} >
            <code className={`language-${model.language}`}>{props.children}</code>
          </pre>
        </div>
      </div>

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <Settings.Input
          editMode={editMode}
          value={model.caption}
          onChange={value => updateProperty(value, 'caption')}
          editor={editor}
          model={model}
          placeholder="Enter an optional caption for this code block"
        />
      </div>
    </React.Fragment>
  );
};

export const CodeBlockLine = (props: any) => {
  return <div {...props.attributes}>{props.children}</div>;
};
