import * as Immutable from 'immutable';
import { ResourceContent, Activity } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getContentDescription } from 'data/content/utils';
import { getFriendlyName } from '../utils';

export const focusHandler = (
  setAssistive: (s: string) => void,
  content: Immutable.OrderedMap<string, ResourceContent>,
  editorMap: ActivityEditorMap,
  activities: Immutable.Map<string, Activity>,
) => (key: string) => {
  const item = content.get(key) as ResourceContent;
  const desc =
    item.type === 'content'
      ? getContentDescription(item)
      : getFriendlyName(item, editorMap, activities);

  const index = content.keySeq().findIndex((k) => k === key);
  setAssistive(`Listbox. ${index + 1} of ${content.size}. ${desc}.`);
};
