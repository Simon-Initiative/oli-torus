import * as Immutable from 'immutable';
import React, { useState } from 'react';
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
    const updated = Object.assign({}, content, { children });
    props.onEdit(updated);
  };

  return (
    <div className="card" style={ { width: '100%' } }>
      <div className="card-header">Content</div>
      <div className="card-body">
        <Editor value={content.children} onEdit={onEdit} toolbarItems={toolbarItems} />
      </div>
    </div>
  );
};
