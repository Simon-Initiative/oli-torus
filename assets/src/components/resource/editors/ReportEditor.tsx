import React from 'react';
import { ReportContent, ResourceContent } from 'data/content/resource';
import { AddResource } from './AddResource';
import {
  Description,
  Icon,
  OutlineGroup,
  OutlineGroupProps,
  resourceGroupTitle,
} from './OutlineItem';
import { ReportBlock } from './ReportBlock';
import { EditorProps, createEditor } from './createEditor';

interface ReportEditorProps extends EditorProps {
  contentItem: ReportContent;
}

export const ReportEditor = ({
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
}: ReportEditorProps) => {
  
  const onEditChild = (child: ResourceContent) => {
    const updatedContent = {
      ...contentItem,
      children: contentItem.children.map((c) => (c.id === child.id ? child : c)),
    };
    onEdit(updatedContent);
  };

  const showCreateAlternativeModal = () =>
    window.oliDispatch(
      modalActions.display(
        <SelectModal
          title="Select Alternative"
          description="Select Alternative"
          onFetchOptions={() => {
            return Promise.resolve(
              alternativeOptions.map((o) => ({ value: o.id, title: o.name })),
            );
          }}
          onDone={(optionId: string) => {
            window.oliDispatch(modalActions.dismiss());

            const newAlt = createAlternative(optionId);
            const update = {
              ...contentItem,
              children: contentItem.children.push(newAlt),
            };

            onEdit(update);
            setActiveOption(newAlt);
          }}
          onCancel={() => window.oliDispatch(modalActions.dismiss())}
        />,
      ),
    );

  return (
    <ReportBlock
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
            })}
          </div>
        );
      })}

      {/* <AddResource
        index={[...index, contentItem.children.size + 1]}
        parents={[...parents, contentItem]}
        editMode={editMode}
        editorMap={editorMap}
        resourceContext={resourceContext}
        featureFlags={featureFlags}
        onAddItem={onAddItem}
        onRegisterNewObjective={onRegisterNewObjective}
      /> */}
    </ReportBlock>
  );
};

interface ReportOutlineItemProps extends OutlineGroupProps {
  contentItem: ReportContent;
}

export const ReportOutlineItem = (props: ReportOutlineItemProps) => {
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
