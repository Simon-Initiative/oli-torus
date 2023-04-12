import { slateFixer } from './SlateFixer';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { Editor } from 'components/editing/editor/Editor';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { StructuredContent } from 'data/content/resource';
import { ProjectSlug, ResourceSlug } from 'data/types';
import React from 'react';
import { Descendant } from 'slate';

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
  const onSlateEdit = React.useCallback(
    (children: Descendant[]) => {
      onEdit(Object.assign({}, contentItem, { children }));
    },
    [contentItem, onEdit],
  );

  const [value] = React.useState(slateFixer(contentItem));

  return (
    <ErrorBoundary>
      <Editor
        className="structured-content"
        commandContext={{ projectSlug: projectSlug, resourceSlug: resourceSlug }}
        editMode={editMode}
        value={value.children}
        onEdit={onSlateEdit}
        toolbarInsertDescs={toolbarInsertDescs}
      />
    </ErrorBoundary>
  );
};
