import * as Immutable from 'immutable';
import { ActivityReference, ResourceContent } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getContentDescription } from 'data/content/utils';
import { ActivityEditContext } from 'data/content/activity';

export const focusHandler =
  (
    setAssistive: (s: string) => void,
    content: Immutable.OrderedMap<string, ResourceContent>,
    editorMap: ActivityEditorMap,
    activities: Immutable.Map<string, ActivityEditContext>,
  ) =>
  (key: string) => {
    const item = content.get(key) as ResourceContent;
    const desc =
      item.type === 'content'
        ? getContentDescription(item)
        : activities.get((item as ActivityReference).activitySlug)?.friendlyName;

    const index = content.keySeq().findIndex((k) => k === key);
    setAssistive(`Listbox. ${index + 1} of ${content.size}. ${desc}.`);
  };
