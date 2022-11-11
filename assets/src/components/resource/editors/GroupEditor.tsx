import React from 'react';
import { AddResource } from './AddResource';
import { EditorProps, createEditor } from './createEditor';
import { ResourceContent, ResourceGroup } from 'data/content/resource';

interface GroupEditorProps extends EditorProps {
  contentItem: ResourceGroup;
}

export const GroupEditor = ({
  resourceContext,
  editMode,
  projectSlug,
  resourceSlug,
  contentItem,
  index,
  parents,
  activities,
  allObjectives,
  allTags,
  canRemove,
  editorMap,
  objectivesMap,
  graded,
  featureFlags,
  onEdit,
  onEditActivity,
  onAddItem,
  onPostUndoable,
  onRegisterNewObjective,
  onRegisterNewTag,
}: GroupEditorProps) => {
  const onEditChild = (child: ResourceContent) => {
    const updatedContent = {
      ...contentItem,
      children: contentItem.children.map((c) => (c.id === child.id ? child : c)),
    };
    onEdit(updatedContent as ResourceContent);
  };

  const onRemoveChild = (child: ResourceContent) => {
    const updatedContent = {
      ...contentItem,
      children: contentItem.children.filter((i) => i.id !== child.id),
    };
    onEdit(updatedContent as ResourceContent);
  };

  return (
    <>
      {contentItem.children.map((c, childIndex) => {
        return (
          <div key={c.id}>
            <AddResource
              index={[...index, childIndex]}
              parents={[...parents, contentItem]}
              editMode={editMode}
              editorMap={editorMap}
              resourceContext={resourceContext}
              featureFlags={featureFlags}
              onAddItem={onAddItem}
              onRegisterNewObjective={onRegisterNewObjective}
            />
            {createEditor({
              resourceContext,
              contentItem: c,
              index: [...index, childIndex],
              parents: [...parents, contentItem],
              activities,
              editMode,
              resourceSlug,
              projectSlug,
              graded,
              objectivesMap,
              allObjectives,
              allTags,
              editorMap,
              canRemove,
              featureFlags,
              onEdit: onEditChild,
              onEditActivity,
              onRemove: () => onRemoveChild(c),
              onPostUndoable,
              onRegisterNewObjective,
              onRegisterNewTag,
              onAddItem,
            })}
          </div>
        );
      })}
      <AddResource
        index={[...index, contentItem.children.size + 1]}
        parents={[...parents, contentItem]}
        editMode={editMode}
        editorMap={editorMap}
        resourceContext={resourceContext}
        featureFlags={featureFlags}
        onAddItem={onAddItem}
        onRegisterNewObjective={onRegisterNewObjective}
      />
    </>
  );
};
