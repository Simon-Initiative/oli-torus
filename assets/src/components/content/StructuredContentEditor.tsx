import React from 'react';
import { Descendant } from 'slate';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { Editor } from 'components/editing/editor/Editor';
import { SwitchToMarkdownModal } from 'components/editing/editor/SwitchToMarkdownModal';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { MarkdownEditor } from 'components/editing/markdown_editor/MarkdownEditor';
import { useToggle } from 'components/hooks/useToggle';
import { DEFAULT_EDITOR, StructuredContent } from 'data/content/resource';
import { ProjectSlug, ResourceSlug } from 'data/types';
import { slateFixer } from './SlateFixer';

export type StructuredContentEditor = {
  editMode: boolean; // Whether or not we can edit
  contentItem: StructuredContent; // Content to edit
  onEdit: (content: StructuredContent) => void; // Edit handler
  toolbarInsertDescs: CommandDescription[]; // Content insertion options
  projectSlug: ProjectSlug;
  resourceSlug: ResourceSlug;
};

// The resource editor for content
export const StructuredContentEditor = ({
  editMode,
  projectSlug,
  resourceSlug,
  contentItem,
  toolbarInsertDescs,
  onEdit,
}: StructuredContentEditor) => {
  const onContentEdit = React.useCallback(
    (children: Descendant[]) => {
      console.info('onContentEdit', children);
      onEdit(Object.assign({}, contentItem, { children }));
    },
    [contentItem, onEdit],
  );
  const [switchToMarkdownModal, toggleSwitchToMarkdownModal, , closeSwitchModal] = useToggle();
  const changeEditor = (editor: 'markdown' | 'slate') => (_e?: any) => {
    console.info('Switching editor modes', editor);
    closeSwitchModal();
    onEdit({
      ...contentItem,
      editor,
    });
  };

  const [value] = React.useState(slateFixer(contentItem));
  const editorType = contentItem.editor || DEFAULT_EDITOR;

  if (editorType === 'markdown') {
    return (
      <ErrorBoundary>
        <MarkdownEditor
          className="structured-content"
          commandContext={{ projectSlug: projectSlug, resourceSlug: resourceSlug }}
          editMode={editMode}
          value={value.children}
          onSwitchModes={changeEditor('slate')}
          onEdit={onContentEdit}
        />
      </ErrorBoundary>
    );
  } else {
    return (
      <ErrorBoundary>
        <Editor
          className="structured-content"
          commandContext={{ projectSlug: projectSlug, resourceSlug: resourceSlug }}
          editMode={editMode}
          value={value.children}
          onEdit={onContentEdit}
          toolbarInsertDescs={toolbarInsertDescs}
          onSwitchToMarkdown={toggleSwitchToMarkdownModal}
        />
        {switchToMarkdownModal && (
          <SwitchToMarkdownModal
            model={contentItem.children}
            onCancel={toggleSwitchToMarkdownModal}
            onConfirm={changeEditor('markdown')}
          />
        )}
      </ErrorBoundary>
    );
  }
};
