// Factory for creating top level editors, for things like structured

import React from 'react';
import { ResourceContent, ResourceType, Activity } from 'data/content/resource';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { EditorDesc, ActivityEditorMap } from 'data/content/editors';
import { ContentBlock } from './ContentBlock';
import { ActivityBlock } from './ActivityBlock';
import { getToolbarForResourceType } from '../../editing/toolbars/insertion/items';
import { UnsupportedActivity } from '../UnsupportedActivity';
import * as Immutable from 'immutable';
import { TestModeHandler, defaultState } from '../TestModeHandler';
import { valueOr } from 'utils/common';

const unsupported: EditorDesc = {
  deliveryElement: UnsupportedActivity,
  authoringElement: UnsupportedActivity,
  icon: '',
  description: 'Not supported',
  friendlyName: 'Not supported',
  slug: 'unknown',
};

// content or referenced activities
export const createEditor = (
  content: ResourceContent,
  index: number,
  activities: Immutable.Map<string, Activity>,
  editorMap: ActivityEditorMap,
  editMode: boolean,
  resourceSlug: string,
  projectSlug: string,
  graded: boolean,
  objectivesMap: any,
  editorProps: any,
  onEdit: (content: ResourceContent) => void,
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
            graded ? ResourceType.assessment : ResourceType.page)}
          />
      </ContentBlock>
    )
  }

  const activity = activities.get(content.activitySlug);

  if (activity !== undefined) {

    const editor = editorMap[activity.typeSlug]
      ? editorMap[activity.typeSlug]
      : unsupported;

    const previewText = activity.model.authoring?.previewText;

    // Test mode is supported by giving the delivery component a transformed
    // instance of the activity model.  Recognizing that we are in an editing mode
    // we make this robust to problems with transformation so we fallback to the raw
    // model if the transformed model is null (which results from failure to transform)
    const model = valueOr(activity.transformed, activity.model)

    const slugsAsKeys = Object.keys(activity.objectives)
      .reduce((map: any, key) => {
        (activity.objectives as any)[key as any].forEach((slug: string) => {
          map[slug] = true;
        });
        return map;
      },
        {});

    const objectives = Object.keys(slugsAsKeys)
      .map(slug => objectivesMap[slug]);

    const props = {
      model: JSON.stringify(model),
      activitySlug: activity.activitySlug,
      state: JSON.stringify(defaultState(model)),
      graded: false,
    };

    return (
      <ActivityBlock
        {...editorProps}
        contentItem={content}
        label={editor.friendlyName}
        projectSlug={projectSlug}
        resourceSlug={resourceSlug}
        objectives={objectives}
        previewText={previewText}>

        <TestModeHandler model={model}>
          {React.createElement(editor.deliveryElement, props as any)}
        </TestModeHandler>

      </ActivityBlock>
    );
  }

  return (
    <div className="alert alert-danger">There was a problem rendering this content block. The content type may not be supported.</div>
  );
};
