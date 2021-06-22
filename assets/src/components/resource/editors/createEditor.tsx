// Factory for creating top level editors, for things like structured

import React from 'react';
import { ResourceContent, ResourceContext, ResourceType, Activity } from 'data/content/resource';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { EditorDesc, ActivityEditorMap } from 'data/content/editors';
import { ContentBlock } from './ContentBlock';
import { ActivityBlock } from './ActivityBlock';
import { getToolbarForResourceType } from '../../editing/toolbars/insertion/items';
import { UnsupportedActivity } from '../UnsupportedActivity';
import * as Immutable from 'immutable';
import { defaultState } from '../TestModeHandler';
import { ActivityEditContext } from 'data/content/activity';
import { InlineActivityEditor, EditorUpdate } from 'components/activity/InlineActivityEditor';
import { Objective } from 'data/content/objective';

const unsupported: EditorDesc = {
  deliveryElement: UnsupportedActivity,
  authoringElement: UnsupportedActivity,
  icon: '',
  description: 'Not supported',
  friendlyName: 'Not supported',
  slug: 'unknown',
  globallyAvailable: true,
  enabledForProject: true,
};

// content or referenced activities
export const createEditor = (
  contentKey: string,
  resourceContext: ResourceContext,
  content: ResourceContent,
  index: number,
  activities: Immutable.Map<string, ActivityEditContext>,
  editorMap: ActivityEditorMap,
  editMode: boolean,
  resourceSlug: string,
  projectSlug: string,
  graded: boolean,
  objectivesMap: any,
  editorProps: any,
  onEdit: (content: ResourceContent) => void,
  onActivityEdit: (key: string, update: EditorUpdate) => void,
  onRegisterNewObjective: (o: Objective) => void,
): JSX.Element => {
  if (content.type === 'content') {
    return (
      <ContentBlock {...editorProps} contentItem={content} index={index}>
        <StructuredContentEditor
          key={content.id}
          editMode={editMode}
          content={content}
          onEdit={onEdit}
          projectSlug={projectSlug}
          toolbarItems={getToolbarForResourceType(
            graded ? ResourceType.assessment : ResourceType.page,
          )}
        />
      </ContentBlock>
    );
  }

  const activity = activities.get(content.activitySlug);

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
      state: defaultState(activity.model),
      typeSlug: activity.typeSlug,
      editMode: editMode,
      graded: false,
      projectSlug: projectSlug,
      resourceSlug: resourceSlug,
      resourceId: resourceContext.resourceId,
      resourceTitle: resourceContext.title,
      authoringScript: activity.authoringScript,
      authoringElement: activity.authoringElement,
      friendlyName: activity.friendlyName,
      description: activity.description,
      objectives: activity.objectives,
      allObjectives: resourceContext.allObjectives,
      activityId: activity.activityId,
      title: activity.title,
      onEdit: (update: EditorUpdate) => onActivityEdit(activity.activitySlug, update),
      onRegisterNewObjective,
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
