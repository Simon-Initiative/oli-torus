import React, { FocusEventHandler } from 'react';

import { getEditMode } from 'components/editing/elements/utils';
import { useSlate } from 'slate-react';
import { Descendant, Editor as SlateEditor } from 'slate';

import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Editor } from 'components/editing/editor/Editor';
import { blockInsertOptions } from 'components/editing/toolbar/editorToolbar/blocks/blockInsertOptions';
import { MediaItemRequest } from '../../../../activities';

interface Props {
  onEdit: (content: any[]) => void;
  content: Descendant[];
  commandContext: CommandContext;
  onRequestMedia?: (request: MediaItemRequest) => void;
  placeholder?: string;
  className?: string;
  id?: string;
  allowBlockElements?: boolean;
  editorOverride?: SlateEditor;
  fixedToolbar?: boolean;
  onFocus?: FocusEventHandler | undefined;
  onBlur?: FocusEventHandler | undefined;
}

export const InlineEditor: React.FC<Props> = ({
  onEdit,
  content,
  commandContext,
  placeholder,
  className,
  id,
  allowBlockElements = false,
  onRequestMedia,
  editorOverride = undefined,
  fixedToolbar = false,
  onFocus = undefined,
  onBlur = undefined,
}) => {
  const editor = useSlate();
  const editMode = getEditMode(editor);

  return (
    <div contentEditable={false} id={id}>
      <Editor
        className={className}
        placeholder={placeholder}
        commandContext={commandContext}
        editMode={editMode}
        value={content}
        onFocus={onFocus}
        onBlur={onBlur}
        onEdit={onEdit}
        editorOverride={editorOverride}
        fixedToolbar={fixedToolbar}
        toolbarInsertDescs={blockInsertOptions({
          type: allowBlockElements ? 'limited' : 'inline',
          onRequestMedia: onRequestMedia,
        })}
      />
    </div>
  );
};
