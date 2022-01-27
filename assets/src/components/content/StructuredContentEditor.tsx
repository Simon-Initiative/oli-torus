import React from 'react';
import { TNode } from '@udecode/plate';
import { StructuredContent } from 'data/content/resource';
import { Editor } from 'components/editing/editor/Editor';
import { ProjectSlug } from 'data/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { CommandDesc, ToolbarItem } from 'components/editing/nodes/commands/interfaces';

export type StructuredContentEditor = {
  editMode: boolean; // Whether or not we can edit
  content: StructuredContent; // Content to edit
  onEdit: (content: StructuredContent) => void; // Edit handler
  toolbarInsertDescs: CommandDesc[]; // Content insertion options
  projectSlug: ProjectSlug;
};

// The resource editor for content
export const StructuredContentEditor = (props: StructuredContentEditor) => {
  const onEdit = React.useCallback(
    (children: TNode[]) => {
      props.onEdit(Object.assign({}, props.content, { children }));
    },
    [props.content, props.onEdit],
  );

  return (
    <ErrorBoundary>
      <Editor
        id={props.content.id}
        className="structured-content"
        commandContext={{ projectSlug: props.projectSlug }}
        editMode={props.editMode}
        value={props.content.children}
        onEdit={onEdit}
        toolbarInsertDescs={props.toolbarInsertDescs}
      />
    </ErrorBoundary>
  );
};
