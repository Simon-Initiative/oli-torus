import React, { useMemo } from 'react';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { ModelElement, TextDirection } from 'data/content/model/elements/types';
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
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const onContentEdit = (children: ModelElement[]) => {
    onEdit(Object.assign({}, contentItem, { children }));
  };

  const onChangeTextDirection = (textDirection: TextDirection) => {
    onEdit({
      ...contentItem,
      textDirection,
    });
  };

  const changeEditor = (editor: 'markdown' | 'slate') => {
    console.info('Switching editor modes', editor, contentItem);
    onEdit({
      ...contentItem,
      editor,
    });
  };

  // The editors aren't true controlled components. They both take initial values. So When we switch between the
  // markdown & slate editors, we need to refresh the initial value so the new editor gets an updated copy.
  const initialEditorValue =
    useMemo(
      () => slateFixer(contentItem),
      // eslint-disable-next-line react-hooks/exhaustive-deps
      [contentItem.editor || ''],
    )?.children || [];

  return (
    <SlateOrMarkdownEditor
      editMode={editMode}
      allowBlockElements={true}
      projectSlug={projectSlug}
      resourceSlug={resourceSlug}
      content={initialEditorValue}
      toolbarInsertDescs={toolbarInsertDescs}
      onEdit={onContentEdit}
      onEditorTypeChange={changeEditor}
      editorType={contentItem.editor || DEFAULT_EDITOR}
      onChangeTextDirection={onChangeTextDirection}
      textDirection={contentItem.textDirection}
    />
  );
};
