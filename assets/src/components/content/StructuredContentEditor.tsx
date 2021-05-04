import React from 'react';
import { Node } from 'slate';
import { StructuredContent } from 'data/content/resource';
import { Selection } from 'data/content/model';
import { Editor } from 'components/editing/editor/Editor';
import { ProjectSlug } from 'data/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { ToolbarItem } from 'components/editing/commands/interfaces';

export type StructuredContentEditor = {
  editMode: boolean; // Whether or not we can edit
  content: StructuredContent; // Content to edit
  onEdit: (content: StructuredContent) => void; // Edit handler
  toolbarItems: ToolbarItem[]; // Toolbar to use
  projectSlug: ProjectSlug;
};

// The resource editor for content
export const StructuredContentEditor = (props: StructuredContentEditor) => {
  const { content, toolbarItems, editMode, projectSlug } = props;

  const onEdit = (children: Node[], selection: Selection) => {
    const updated = Object.assign({}, content, { children, selection });
    props.onEdit(updated);
  };

  return (
    <ErrorBoundary>
      <Editor
        className="structured-content"
        commandContext={{ projectSlug }}
        editMode={editMode}
        value={content.children}
        selection={content.selection}
        onEdit={onEdit}
        toolbarItems={toolbarItems}
      />
    </ErrorBoundary>
  );
};
