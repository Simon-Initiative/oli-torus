import * as Immutable from 'immutable';
import React from 'react';
import { ResourceContent, Activity, ResourceType } from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { UnsupportedActivity } from './UnsupportedActivity';
import { getToolbarForResourceType } from './toolbar';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { ResourceContentFrame } from 'components/content/ResourceContentFrame';
import { ProjectSlug, ResourceSlug } from 'data/types';


export type EditorsProps = {
  editMode: boolean,              // Whether or not we can edit
  content: Immutable.List<ResourceContent>,     // Content of the resource
  onEdit: (content: Immutable.List<ResourceContent>) => void,
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
  graded: boolean,
  activities: Immutable.Map<string, Activity>,
  projectSlug: ProjectSlug,
  resourceSlug: ResourceSlug,
};


// The list of editors
export const Editors = (props: EditorsProps) => {

  const { editorMap, editMode, graded,
    content, activities, projectSlug, resourceSlug } = props;

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
        toolbarItems={getToolbarForResourceType(
          graded ? ResourceType.assessment : ResourceType.page)}/>, 'Content'];
    }

    const unsupported : EditorDesc = {
      deliveryElement: UnsupportedActivity,
      authoringElement: UnsupportedActivity,
      icon: '',
      description: 'Not supported',
      friendlyName: 'Not supported',
      slug: 'unknown',
    };

    const activity = activities.get(content.activitySlug);
    let editor;
    let props;
    if (activity !== undefined) {
      editor = editorMap[activity.typeSlug]
        ? editorMap[activity.typeSlug] : unsupported;

      props = {
        model: JSON.stringify(activity !== undefined ? activity.model : {}),
      };

    } else {
      editor = unsupported;
      props = {};
    }

    return [React.createElement(editor.deliveryElement,
      props as any), editor.friendlyName];

  };

  const editors = content.map((c, index) => {

    const onEdit = (u : ResourceContent) => props.onEdit(content.set(index, u));
    const onRemove = () => props.onEdit(content.remove(index));

    const [editor, label] = createEditor(c, onEdit);

    const editingLink = c.type === 'activity-reference'
      ? `/project/${projectSlug}/resource/${resourceSlug}/activity/${c.activitySlug}` : undefined;

    return (
      <ResourceContentFrame
        key={c.id}
        allowRemoval={content.size > 1}
        editMode={editMode}
        label={label}
        editingLink={editingLink}
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
