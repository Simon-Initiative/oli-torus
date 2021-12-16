import React from 'react';
import { Descendant } from 'slate';
import { StructuredContent } from 'data/content/resource';
import { Editor } from 'components/editing/editor/Editor';
import { ProjectSlug } from 'data/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { ToolbarItem } from 'components/editing/toolbar/interfaces';

export type StructuredContentEditor = {
  editMode: boolean; // Whether or not we can edit
  content: StructuredContent; // Content to edit
  onEdit: (content: StructuredContent) => void; // Edit handler
  toolbarItems: ToolbarItem[]; // Toolbar to use
  projectSlug: ProjectSlug;
};

// The resource editor for content
export const StructuredContentEditor = (props: StructuredContentEditor) => {
  const onEdit = React.useCallback(
    (children: Descendant[]) => {
      props.onEdit(Object.assign({}, props.content, { children }));
    },
    [props.content, props.onEdit],
  );

  return (
    <ErrorBoundary>
      <Editor
        className="structured-content"
        commandContext={{ projectSlug: props.projectSlug }}
        editMode={props.editMode}
        value={props.content.children}
        onEdit={onEdit}
        toolbarItems={props.toolbarItems}
      />
    </ErrorBoundary>
  );
};
