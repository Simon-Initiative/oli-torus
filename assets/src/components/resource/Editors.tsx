import * as Immutable from 'immutable';
import React from 'react';
import { ResourceContent, ResourceType } from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { UnsupportedActivity } from './UnsupportedActivity';
import { getToolbarForResourceType } from './toolbar';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { ResourceContentFrame } from 'components/content/ResourceContentFrame';

export type EditorsProps = {
  editMode: boolean,              // Whether or not we can edit
  content: Immutable.List<ResourceContent>,     // Content of the resource
  onEdit: (content: Immutable.List<ResourceContent>) => void,
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
  resourceType: ResourceType,
};

// The list of editors
export const Editors = (props: EditorsProps) => {

  const { editorMap, editMode, resourceType, content } = props;

  // Factory for creating top level editors, for things like structured
  // content or referenced activities
  const createEditor = (
    editorMap: ActivityEditorMap,
    content: ResourceContent,
    editMode: boolean,
    onEdit: (content: ResourceContent) => void,
    onRemove: () => void,
    contentSize: number,
    ) : JSX.Element => {

    if (content.type === 'content') {
      return (
        <ResourceContentFrame
          key={content.id}
          allowRemoval={contentSize > 1} editMode={editMode} label="Content" onRemove={onRemove}>
          <StructuredContentEditor
            key={content.id}
            editMode={editMode}
            content={content}
            onEdit={onEdit}
            toolbarItems={getToolbarForResourceType(resourceType)}/>
        </ResourceContentFrame>
      );
    }

    const unsupported : EditorDesc = {
      deliveryElement: UnsupportedActivity,
      authoringElement: UnsupportedActivity,
      icon: '',
      description: 'Not supported',
      friendlyName: 'Not supported',
    };

    const editor = editorMap[content.type]
      ? editorMap[content.type] : unsupported;

    const props = {

    };

    return (
      <ResourceContentFrame
        key={content.id}
        allowRemoval={contentSize > 1}
        editMode={editMode}
        label={editor.friendlyName}
        onRemove={onRemove}>

        {React.createElement(editor.deliveryElement, props)}
      </ResourceContentFrame>
    );
  };

  const editors = content.map((c, index) => {

    const onEdit = (u : ResourceContent) => props.onEdit(content.set(index, u));
    const onRemove = () => props.onEdit(content.remove(index));

    return createEditor(editorMap, c, editMode, onEdit, onRemove, content.size);
  });

  return (
    <div className="d-flex flex-column flex-grow-1">
      {editors}
    </div>
  );
};
