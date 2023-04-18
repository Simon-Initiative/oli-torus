import * as Immutable from 'immutable';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import { ActivityReference, ResourceContent } from 'data/content/resource';
import { ActivityPayload, DragPayload } from './interfaces';

export const getFriendlyName = (
  item: ActivityReference,
  editorMap: ActivityEditorMap,
  activities: Immutable.Map<string, ActivityEditContext>,
) => {
  const activity = activities.get(item.activitySlug);
  return editorMap[(activity as any).typeSlug].friendlyName;
};

export const getDragPayload = (
  contentItem: ResourceContent,
  activities: Immutable.Map<string, ActivityEditContext>,
  projectSlug: string,
): DragPayload => {
  if (activities.has((contentItem as ActivityReference).activitySlug)) {
    const activity = activities.get((contentItem as ActivityReference).activitySlug);
    return {
      type: 'ActivityPayload',
      id: contentItem.id,
      reference: contentItem,
      activity: activity as ActivityEditContext,
      project: projectSlug,
    } as ActivityPayload;
  }

  return contentItem;
};

export const scrollToResourceEditor = (contentId: string) => {
  setTimeout(() => {
    const element = document.querySelector(`#resource-editor-${contentId}`);

    if (element) {
      const headerOffset = 60;
      const elementPosition = element.getBoundingClientRect().top;
      const offsetPosition = elementPosition + window.pageYOffset - headerOffset;

      window.scrollTo({
        top: offsetPosition,
        behavior: 'smooth',
      });
    }
  });
};
