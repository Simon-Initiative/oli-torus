import React, { useState } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editor/editors/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';
import * as Settings from 'components/editor/editors/settings/Settings';
import { CodeSettings } from 'components/editor/editors/code/CodeSettings';


export interface CodeProps extends EditorProps<ContentModel.Code> {
}

export const CodeEditor = (props: CodeProps) => {

  const { editor } = props;
  const { model } = props;
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const editMode = getEditMode(editor);

  const onEdit = (updated: ContentModel.Code) => {
    updateModel<ContentModel.Code>(editor, model, updated);
    setIsPopoverOpen(false);
  };

  const onRemove = () => {
    ($('#remove-button') as any).tooltip('hide');

    const path = ReactEditor.findPath(editor, model);
    Transforms.removeNodes(editor, { at: path });

    setIsPopoverOpen(false);
  };

  const contentFn = () => <CodeSettings
    model={model}
    editMode={editMode}
    commandContext={props.commandContext}
    onRemove={onRemove}
    onEdit={onEdit} />;

  return (
    <div {...props.attributes} className="code-editor">
      <div className="code-editor-content">
        <pre style={{ fontFamily: 'Menlo, Monaco, Courier New, monospace' }} >
          <code className={`language-${model.language}`}>{props.children}</code>
        </pre>
      </div>

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <Settings.ToolPopupButton
          contentFn={contentFn}
          setIsPopoverOpen={setIsPopoverOpen}
          isPopoverOpen={isPopoverOpen}
          label="Code" />
        <Settings.Caption caption={model.caption} />
      </div>
    </div>
  );
};

export const CodeBlockLine = (props: any) => {
  return <div {...props.attributes}>{props.children}</div>;
};
