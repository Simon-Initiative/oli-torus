import React from 'react';
import { StructuredContent } from 'data/content/resource';
import { Editor } from 'components/editor/Editor';
import { ToolbarItem } from 'components/resource/toolbar';

export type StructuredContentEditor = {
  editMode: boolean,              // Whether or not we can edit
  content: StructuredContent,     // Content to edit
  onEdit: (content: StructuredContent) => void, // Edit handler
  toolbarItems: ToolbarItem[],    // Toolbar to use
};

// The resource editor
export const StructuredContentEditor = (props: StructuredContentEditor) => {

  const { content, toolbarItems, editMode } = props;

  const onEdit = (children: any) => {
    console.log('edit')
    const updated = Object.assign({}, content, { children });
    props.onEdit(updated);
  };
  return (
    <Editor
      editMode={editMode}
      value={content.children}
      onEdit={onEdit}
      toolbarItems={toolbarItems} />
  );
};
