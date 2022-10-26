import React from 'react';
import {
  AlternativeContent,
  AlternativesContent,
  ResourceContent,
  ResourceGroup,
} from 'data/content/resource';
import { GroupBlock } from './GroupBlock';
import { AddResource } from './AddResource';
import { EditorProps, createEditor } from './createEditor';
import {
  Description,
  ExpandToggle,
  OutlineItem,
  OutlineItemProps,
  OutlineGroup,
  OutlineGroupProps,
  resourceGroupTitle,
} from './OutlineItem';

interface AlternativesEditorProps extends EditorProps {
  contentItem: AlternativesContent;
}

export const AlternativesEditor = ({
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
}: AlternativesEditorProps) => {
  const onEditChild = (child: AlternativeContent) => {
    const updatedContent = {
      ...contentItem,
      children: contentItem.children.map((c) => (c.id === child.id ? child : c)),
    };
    onEdit(updatedContent);
  };

  const contentBreaksExist = contentItem.children
    .toArray()
    .some((v: ResourceContent) => v.type === 'break');

  return (
    <GroupBlock
      editMode={editMode}
      contentItem={contentItem}
      parents={parents}
      canRemove={canRemove}
      onRemove={onRemove}
      onEdit={onEdit}
      contentBreaksExist={contentBreaksExist}
    >
      Alternatives Editor
      {/* {contentItem.children.map((c, childIndex) => {
        const onRemoveChild = () =>
          onEdit({
            ...contentItem,
            children: contentItem.children.filter((i) => i.id !== c.id),
          });

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
              contentBreaksExist,
              onEdit: onEditChild,
              onEditActivity,
              onRemove: onRemoveChild,
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
      /> */}
    </GroupBlock>
  );
};

interface AlternativesOutlineItemProps extends OutlineItemProps {
  contentItem: AlternativesContent;
  expanded: boolean;
  toggleCollapsibleGroup: (id: string) => void;
}

export const AlternativesOutlineItem = (props: AlternativesOutlineItemProps) => {
  const { id, contentItem, expanded, toggleCollapsibleGroup } = props;

  return (
    <OutlineItem {...props}>
      <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
      <Description title={resourceGroupTitle(contentItem)}>
        {contentItem.children.size} items
      </Description>
    </OutlineItem>
  );
};

interface AlternativeOutlineItemProps extends OutlineGroupProps {
  contentItem: AlternativeContent;
  expanded: boolean;
  toggleCollapsibleGroup: (id: string) => void;
}

export const AlternativeOutlineItem = (props: AlternativeOutlineItemProps) => {
  const { id, contentItem, expanded, toggleCollapsibleGroup } = props;

  return (
    <OutlineGroup {...props}>
      <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
      <Description title={alternatveGroupTitle(contentItem)}>
        {contentItem.children.size} items
      </Description>
    </OutlineGroup>
  );
};

const alternatveGroupTitle = (alternative: AlternativeContent) => alternative.value;
