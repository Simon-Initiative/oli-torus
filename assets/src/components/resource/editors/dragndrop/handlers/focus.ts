import * as Immutable from 'immutable';
import { ResourceContent, Activity } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getContentDescription } from 'data/content/utils';
import { getFriendlyName } from '../utils';

export const focusHandler = (
  setAssistive: (s: string) => void,
  content: Immutable.List<ResourceContent>,
  editorMap: ActivityEditorMap,
  activities: Immutable.Map<string, Activity>,
) => (index: number) => {
  console.log('focusing');
  const item = content.get(index) as ResourceContent;
  const desc =
    item.type === 'content'
      ? getContentDescription(item)
      : getFriendlyName(item, editorMap, activities);

  setAssistive(`Listbox. ${index + 1} of ${content.size}. ${desc}.`);
};
