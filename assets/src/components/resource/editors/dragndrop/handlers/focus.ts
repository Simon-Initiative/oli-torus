import * as Immutable from 'immutable';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import { ActivityReference, ResourceContent } from 'data/content/resource';
import { getContentDescription } from 'data/content/utils';
import { PageEditorContent } from 'data/editor/PageEditorContent';

export const focusHandler =
  (
    setAssistive: (s: string) => void,
    content: PageEditorContent,
    editorMap: ActivityEditorMap,
    activities: Immutable.Map<string, ActivityEditContext>,
  ) =>
  (key: string) => {
    const item = content.find(key) as ResourceContent;
    const desc =
      item.type === 'content'
        ? getContentDescription(item)
        : activities.get((item as ActivityReference).activitySlug)?.friendlyName;

    const index = content.flattenedIndex(key);
    setAssistive(`Listbox. ${index + 1} of ${content.count()}. ${desc}.`);
  };
