import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { Editor } from 'components/editing/editor/Editor';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { StructuredContent } from 'data/content/resource';
import { ProjectSlug } from 'data/types';
import React from 'react';
import { Descendant } from 'slate';
import { slateFixer } from './SlateFixer';

export type StructuredContentEditor = {
  editMode: boolean; // Whether or not we can edit
  content: StructuredContent; // Content to edit
  onEdit: (content: StructuredContent) => void; // Edit handler
  toolbarInsertDescs: CommandDescription[]; // Content insertion options
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

  const [value, setValue] = React.useState(slateFixer(props.content));

  return (
    <ErrorBoundary>
      <Editor
        className="structured-content"
        commandContext={{ projectSlug: props.projectSlug }}
        editMode={props.editMode}
        value={value.children}
        onEdit={onEdit}
        toolbarInsertDescs={props.toolbarInsertDescs}
      />
    </ErrorBoundary>
  );
};
