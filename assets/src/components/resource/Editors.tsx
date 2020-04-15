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

function createEditorWithLabel(
  content: ResourceContent, resourceType: ResourceType,
  editMode: boolean, onEdit: (content: ResourceContent) => void) {


}

// The list of editors
export const Editors = (props: EditorsProps) => {

  const { editorMap, editMode, resourceType, content } = props;

  // Factory for creating top level editors, for things like structured
  // content or referenced activities
  const createEditor = (
    content: ResourceContent,
    onEdit: (content: ResourceContent) => void,
    ) : [JSX.Element, string] => {

    if (content.type === 'content') {
      return [<StructuredContentEditor
        key={content.id}
        editMode={editMode}
        content={content}
        onEdit={onEdit}
        toolbarItems={getToolbarForResourceType(resourceType)}/>, 'Content'];
    }

    const unsupported : EditorDesc = {
      deliveryElement: UnsupportedActivity,
      authoringElement: UnsupportedActivity,
      icon: '',
      description: 'Not supported',
      friendlyName: 'Not supported',
      slug: 'unknown',
    };

    const editor = editorMap[content.type]
      ? editorMap[content.type] : unsupported;

    const props = {};

    return [React.createElement(editor.deliveryElement, props), editor.friendlyName];

  };

  const editors = content.map((c, index) => {

    const onEdit = (u : ResourceContent) => props.onEdit(content.set(index, u));
    const onRemove = () => props.onEdit(content.remove(index));

    const [editor, label] = createEditor(c, onEdit);

    return (
      <ResourceContentFrame
        key={c.id}
        allowRemoval={content.size > 1}
        editMode={editMode}
        label={label}
        onRemove={onRemove}>

        {editor}

      </ResourceContentFrame>
    );
  });

  return (
    <div className="d-flex flex-column flex-grow-1">
      {editors}
    </div>
  );
};
