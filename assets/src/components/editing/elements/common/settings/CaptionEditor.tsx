import React from 'react';
import { Caption, CaptionV2, ModelElement } from 'data/content/model/elements/types';
import { getEditMode } from 'components/editing/elements/utils';
import { useSlate } from 'slate-react';
import { Model } from 'data/content/model/elements/factories';
import { Descendant } from 'slate';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Editor } from 'components/editing/editor/Editor';
import { blockInsertOptions } from 'components/editing/toolbar/editorToolbar/blocks/blockInsertOptions';

const defaultCaption = (text = '') => [Model.p(text)];

interface Props {
  onEdit: (caption: CaptionV2) => void;
  model: ModelElement & { caption?: Caption };
  commandContext: CommandContext;
}
export const CaptionEditor = (props: Props) => {
  const editor = useSlate();
  const editMode = getEditMode(editor);

  return (
    <div contentEditable={false}>
      <Editor
        className="settings-input"
        placeholder="Caption (optional)"
        commandContext={props.commandContext}
        editMode={editMode}
        value={
          (Array.isArray(props.model.caption)
            ? props.model.caption
            : defaultCaption(props.model.caption)) as Descendant[]
        }
        onEdit={(content: CaptionV2) => {
          props.onEdit(content);
        }}
        toolbarInsertDescs={blockInsertOptions({
          type: 'inline',
          onRequestMedia: () => {},
        })}
      />
    </div>
  );
};
