import React from 'react';
import { ActivityReference, ResourceContent, ResourceContext } from 'data/content/resource';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { ContentBlock } from './ContentBlock';
import { ActivityBlock } from './ActivityBlock';
import * as Immutable from 'immutable';
import { ActivityEditContext } from 'data/content/activity';
import { InlineActivityEditor, EditorUpdate } from 'components/activity/InlineActivityEditor';
import { Objective } from 'data/content/objective';
import { Undoable } from 'components/activities/types';
import { ActivityBankSelection } from './ActivityBankSelection';
import { Tag } from 'data/content/tags';
import { ActivityEditorMap } from 'data/content/editors';
import { defaultActivityState } from 'data/activities/utils';
import { getToolbarForContentType } from 'components/editing/toolbar/utils';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';

// content or referenced activities
export const createEditor = (
  resourceContext: ResourceContext,
  content: ResourceContent,
  index: number,
  activities: Immutable.Map<string, ActivityEditContext>,
  editMode: boolean,
  resourceSlug: string,
  projectSlug: string,
  graded: boolean,
  objectivesMap: any,
  editorProps: any,
  allObjectives: Objective[],
  allTags: Tag[],
  editorMap: ActivityEditorMap,
  onEdit: (content: ResourceContent) => void,
  onActivityEdit: (key: string, update: EditorUpdate) => void,
  onPostUndoable: (key: string, undoable: Undoable) => void,
  onRegisterNewObjective: (o: Objective) => void,
  onRegisterNewTag: (o: Tag) => void,
  onAddItem: AddCallback,
): JSX.Element => {
  if (content.type === 'selection') {
    return (
      <ContentBlock {...editorProps} contentItem={content} index={index}>
        <ActivityBankSelection
          editorMap={editorMap}
          key={content.id}
          editMode={editMode}
          selection={content}
          onChange={onEdit}
          projectSlug={projectSlug}
          allObjectives={Immutable.List<Objective>(allObjectives)}
          allTags={Immutable.List<Tag>(allTags)}
          onRegisterNewObjective={onRegisterNewObjective}
          onRegisterNewTag={onRegisterNewTag}
        />
      </ContentBlock>
    );
  }

  if (content.type === 'content') {
    return (
      <ContentBlock {...editorProps} contentItem={content} index={index}>
        <StructuredContentEditor
          key={content.id}
          editMode={editMode}
          content={content}
          onEdit={onEdit}
          projectSlug={projectSlug}
          toolbarInsertDescs={getToolbarForContentType({
            type: 'all',
            resourceContext,
            onAddItem,
            editorMap,
            index,
          })}
        />
      </ContentBlock>
    );
  }

  const activity = activities.get((content as ActivityReference).activitySlug);

  if (activity !== undefined) {
    const previewText = activity.model.authoring?.previewText;

    const slugsAsKeys = Object.keys(activity.objectives).reduce((map: any, key) => {
      (activity.objectives as any)[key as any].forEach((slug: string) => {
        map[slug] = true;
      });
      return map;
    }, {});

    const objectives = Object.keys(slugsAsKeys).map((slug) => objectivesMap[slug]);

    const props = {
      model: activity.model,
      activitySlug: activity.activitySlug,
      state: defaultActivityState(activity.model),
      typeSlug: activity.typeSlug,
      editMode: editMode,
      graded: false,
      projectSlug: projectSlug,
      resourceSlug: resourceSlug,
      resourceId: resourceContext.resourceId,
      resourceTitle: resourceContext.title,
      authoringElement: activity.authoringElement,
      friendlyName: activity.friendlyName,
      description: activity.description,
      objectives: activity.objectives,
      allObjectives,
      tags: activity.tags,
      allTags,
      activityId: activity.activityId,
      title: activity.title,
      onEdit: (update: EditorUpdate) => onActivityEdit(activity.activitySlug, update),
      onPostUndoable: (undoable: Undoable) => onPostUndoable(activity.activitySlug, undoable),
      onRegisterNewObjective,
      onRegisterNewTag,
      banked: false,
    };

    return (
      <ActivityBlock
        {...editorProps}
        contentItem={content}
        label={activity.friendlyName}
        projectSlug={projectSlug}
        resourceSlug={resourceSlug}
        objectives={objectives}
        previewText={previewText}
      >
        <InlineActivityEditor {...props} />
      </ActivityBlock>
    );
  }

  return (
    <div className="alert alert-danger">
      There was a problem rendering this content block. The content type may not be supported.
    </div>
  );
};
