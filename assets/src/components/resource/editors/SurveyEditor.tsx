import React from 'react';
import { ResourceContent, SurveyContent } from 'data/content/resource';
import { AddResource } from './AddResource';
import {
  Description,
  Icon,
  OutlineGroup,
  OutlineGroupProps,
  resourceGroupTitle,
} from './OutlineItem';
import { SurveyBlock } from './SurveyBlock';
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
  contentBreaksExist,
  onEdit,
  onEditActivity,
  onAddItem,
  onRemove,
  onPostUndoable,
  onRegisterNewObjective,
  onRegisterNewTag,
  onDuplicate,
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
              contentBreaksExist,
              onEdit: onEditChild,
              onEditActivity,
              onRemove,
              onPostUndoable,
              onRegisterNewObjective,
              onRegisterNewTag,
              onAddItem,
              onDuplicate,
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

interface SurveyOutlineItemProps extends OutlineGroupProps {
  contentItem: SurveyContent;
}

export const SurveyOutlineItem = (props: SurveyOutlineItemProps) => {
  const { contentItem } = props;

  return (
    <OutlineGroup {...props}>
      <Icon iconName="fas fa-poll" />
      <Description title={resourceGroupTitle(contentItem)}>
        {contentItem.children.size} items
      </Description>
    </OutlineGroup>
  );
};
