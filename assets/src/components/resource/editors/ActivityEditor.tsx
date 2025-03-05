import React from 'react';
import { Undoable } from 'components/activities/types';
import { EditorUpdate, InlineActivityEditor } from 'components/activity/InlineActivityEditor';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityReference } from 'data/content/resource';
import { ActivityBlock } from './ActivityBlock';
import { Description, Icon, OutlineItem, OutlineItemProps } from './OutlineItem';
import { EditorError, EditorProps } from './createEditor';

interface ActivityEditorProps extends EditorProps {
  contentItem: ActivityReference;
}

export const ActivityEditor = ({
  resourceContext,
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
  onDuplicate,
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
          variables={activity.variables}
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
          revisionHistoryLink={false}
          contentBreaksExist={contentBreaksExist}
          optionalContentTypes={resourceContext.optionalContentTypes}
          canRemove={canRemove}
          onRemove={() => onRemove(contentItem.id)}
          onEdit={(update: EditorUpdate) => onEditActivity(activity.activitySlug, update)}
          onPostUndoable={(undoable: Undoable) => onPostUndoable(activity.activitySlug, undoable)}
          onRegisterNewObjective={onRegisterNewObjective}
          onRegisterNewTag={onRegisterNewTag}
          onDuplicate={() => onDuplicate(activity)}
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
