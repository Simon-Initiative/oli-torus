import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ResourceContent, ResourceGroup } from 'data/content/resource';
import { AddResource } from './AddResource';
import styles from './ContentBlock.modules.scss';
import { EditorProps, createEditor } from './createEditor';

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
  onRemove,
  onPostUndoable,
  onRegisterNewObjective,
  onRegisterNewTag,
  onDuplicate,
}: GroupEditorProps) => {
  const onEditChild = (child: ResourceContent) => {
    const updatedContent = {
      ...contentItem,
      children: contentItem.children.map((c) => (c.id === child.id ? child : c)),
    };
    onEdit(updatedContent as ResourceContent);
  };

  const contentBreaksExist = contentItem.children.some((v: ResourceContent) => v.type === 'break');

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
              contentBreaksExist,
              onEdit: onEditChild,
              onEditActivity,
              onRemove: onRemove,
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
    </>
  );
};

interface GroupBlockProps {
  editMode: boolean;
  contentItem: ResourceGroup;
  parents: ResourceContent[];
  canRemove: boolean;
  onEdit: (contentItem: ResourceGroup) => void;
  onRemove: () => void;
}
export const GroupBlock = (props: PropsWithChildren<GroupBlockProps>) => {
  const { editMode, contentItem, canRemove, children, onRemove } = props;

  return (
    <div id={`resource-editor-${contentItem.id}`} className={styles.groupBlock}>
      <div className={styles.groupBlockHeader}>
        <div className="flex-grow-1"></div>
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      {children}
    </div>
  );
};
