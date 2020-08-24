import React, { useState } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Editor } from 'slate';
import { updateModel, getEditMode } from 'components/editor/editors/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';
import * as Settings from 'components/editor/editors/settings/Settings';
import { CodeSettings } from 'components/editor/editors/code/CodeSettings';

export interface CodeProps extends EditorProps<ContentModel.Code> { }

export const CodeEditor = (props: CodeProps) => {

  const { model, editor } = props;

  const editMode = getEditMode(editor);

  const updateProperty = (value: string, key: string) =>
    onEdit(Object.assign({}, model, { [key]: value }));

  const onEdit = (updated: ContentModel.Code) => {
    console.log('updated', updated)
    updateModel<ContentModel.Code>(editor, model, updated);
  };

  const onRemove = () => {
    ($('#remove-button') as any).tooltip('hide');

    const path = ReactEditor.findPath(editor, model);
    Transforms.removeNodes(editor, { at: path });
  };

  const contentFn = () => <CodeSettings
    model={model}
    editMode={editMode}
    commandContext={props.commandContext}
    onRemove={onRemove}
    onEdit={onEdit} />;

  return (
    <React.Fragment>
      <div {...props.attributes} className="code-editor">
        <div contentEditable={false} style={{ userSelect: 'none' }}>
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
          value={model.caption}
          onChange={value => updateProperty(value, 'caption')}
          editor={editor}
          model={model}
          placeholder="Type caption for code block"
        />
      </div>
    </React.Fragment>
  );
};

export const CodeBlockLine = (props: any) => {
  return <div {...props.attributes}>{props.children}</div>;
};
