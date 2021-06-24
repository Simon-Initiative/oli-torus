import { ActivityReference, ResourceContent } from 'data/content/resource';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import * as Immutable from 'immutable';
import { DragPayload, ActivityPayload, UnknownPayload } from './interfaces';

export const getFriendlyName = (
  item: ActivityReference,
  editorMap: ActivityEditorMap,
  activities: Immutable.Map<string, ActivityEditContext>) => {

  const activity = activities.get(item.activitySlug);
  return editorMap[(activity as any).typeSlug].friendlyName;
};

export const getDragPayload = (
  contentItem: ResourceContent,
  activities: Immutable.Map<string, ActivityEditContext>,
  projectSlug: string,
): DragPayload => {
  if (contentItem.type === 'content') {
    return contentItem;
  }
  if (activities.has(contentItem.activitySlug)) {
    const activity = activities.get(contentItem.activitySlug);
    return {
      type: 'ActivityPayload',
      id: contentItem.id,
      reference: contentItem,
      activity: activity as ActivityEditContext,
      project: projectSlug,
    } as ActivityPayload;
  }
  return {
    type: 'UnknownPayload',
    data: contentItem,
    id: contentItem.id,
  } as UnknownPayload;
};
