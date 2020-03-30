import * as Immutable from 'immutable';
import React from 'react';
import { ResourceContent, ResourceType } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { UnsupportedActivity } from './UnsupportedActivity';
import { getToolbarForResourceType } from './toolbar';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';

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
    onEdit: (content: ResourceContent) => void,
    editMode: boolean) : JSX.Element => {

    if (content.type === 'content') {
      return (
        <StructuredContentEditor
          key={content.id}
          editMode={editMode}
          content={content}
          onEdit={onEdit}
          toolbarItems={getToolbarForResourceType(resourceType)}/>
      );
    }

    const element = editorMap[content.type]
      ? editorMap[content.type].deliveryElement : UnsupportedActivity;

    const props = {

    };

    return React.createElement(element, props);
  };

  const editors = content.map((c, i) => {
    const onEdit = (updatedComponent : ResourceContent) => {
      const updated = content.set(i, updatedComponent);
      props.onEdit(updated);
    };
    return createEditor(editorMap, c, onEdit, editMode);
  });

  return (
    <div className="d-flex flex-column flex-grow-1">
      {editors}
    </div>
  );
};
