import React from 'react';
import { ActivityReference } from 'data/content/resource';
import { ActivityBlock } from './ActivityBlock';
import { InlineActivityEditor, EditorUpdate } from 'components/activity/InlineActivityEditor';
import { Undoable } from 'components/activities/types';
import { EditorProps, EditorError } from './createEditor';

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
          onRemove={onRemove}
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
