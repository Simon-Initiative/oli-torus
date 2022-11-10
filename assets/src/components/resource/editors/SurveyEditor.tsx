import React from 'react';
import { ResourceContent, SurveyContent } from 'data/content/resource';
import { SurveyBlock } from './SurveyBlock';
import { AddResource } from './AddResource';
import { EditorProps, createEditor } from './createEditor';

interface SurveyEditorProps extends EditorProps {
  contentItem: SurveyContent;
}

export const SurveyEditor = ({
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
  onRemove,
  onPostUndoable,
  onRegisterNewObjective,
  onRegisterNewTag,
}: SurveyEditorProps) => {
  const onEditChild = (child: ResourceContent) => {
    const updatedContent = {
      ...contentItem,
      children: contentItem.children.map((c) => (c.id === child.id ? child : c)),
    };
    onEdit(updatedContent);
  };

  return (
    <SurveyBlock
      editMode={editMode}
      contentItem={contentItem}
      canRemove={canRemove}
      onRemove={() => onRemove(contentItem.id)}
      onEdit={onEdit}
    >
      {contentItem.children.map((c, childIndex) => {
        return (
          <div key={c.id}>
            <AddResource
              onRegisterNewObjective={onRegisterNewObjective}
              index={[...index, childIndex]}
              parents={[...parents, contentItem]}
              editMode={editMode}
              editorMap={editorMap}
              resourceContext={resourceContext}
              featureFlags={featureFlags}
              onAddItem={onAddItem}
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
              contentBreaksExist: false,
              onEdit: onEditChild,
              onEditActivity,
              onRemove,
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
    </SurveyBlock>
  );
};
