import React from 'react';
import { ActivityReference, ResourceContent } from 'data/content/resource';
import { ActivityBlock } from './ActivityBlock';
import { InlineActivityEditor, EditorUpdate } from 'components/activity/InlineActivityEditor';
import { Undoable } from 'components/activities/types';
import { EditorProps, EditorError } from './createEditor';
import { ActivityEditContext } from 'data/content/activity';
import { Description, Icon, OutlineItem, OutlineItemProps } from './OutlineItem';

interface ActivityEditorProps extends EditorProps {
  contentItem: ActivityReference;
}

export const ActivityEditor = ({
  editMode,
  projectSlug,
  contentItem,
  activities,
  allObjectives,
  allTags,
  canRemove,
  contentBreaksExist,
  onEditActivity,
  onRemove,
  onPostUndoable,
  onRegisterNewObjective,
  onRegisterNewTag,
}: ActivityEditorProps) => {
  const activity = activities.get(contentItem.activitySlug);

  if (activity !== undefined) {
    return (
      <ActivityBlock
        editMode={editMode}
        contentItem={contentItem}
        canRemove={canRemove}
        onRemove={onRemove}
      >
        <InlineActivityEditor
          model={activity.model}
          activitySlug={activity.activitySlug}
          typeSlug={activity.typeSlug}
          editMode={editMode}
          projectSlug={projectSlug}
          authoringElement={activity.authoringElement}
          friendlyName={activity.friendlyName}
          description={activity.description}
          objectives={activity.objectives}
          allObjectives={allObjectives}
          tags={activity.tags}
          allTags={allTags}
          activityId={activity.activityId}
          title={activity.title}
          banked={false}
          contentBreaksExist={contentBreaksExist}
          canRemove={canRemove}
          onRemove={() => onRemove(contentItem.id)}
          onEdit={(update: EditorUpdate) => onEditActivity(activity.activitySlug, update)}
          onPostUndoable={(undoable: Undoable) => onPostUndoable(activity.activitySlug, undoable)}
          onRegisterNewObjective={onRegisterNewObjective}
          onRegisterNewTag={onRegisterNewTag}
        />
      </ActivityBlock>
    );
  } else {
    return <EditorError />;
  }
};

interface ActivityEditorContentOutlineItemProps extends OutlineItemProps {
  activity: ActivityEditContext;
}

export const ActivityEditorContentOutlineItem = (props: ActivityEditorContentOutlineItemProps) => {
  const { activity } = props;
  return (
    <OutlineItem {...props}>
      <Icon iconName="fas fa-shapes" />
      <Description title={activity?.title}>{getActivityDescription(activity)}</Description>
    </OutlineItem>
  );
};

const getActivityDescription = (activity: ActivityEditContext) => {
  return activity.model.authoring?.previewText || <i>No content</i>;
};
