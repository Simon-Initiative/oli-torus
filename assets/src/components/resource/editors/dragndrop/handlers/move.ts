import { ResourceContent, Activity } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getFriendlyName } from '../utils';
import * as Immutable from 'immutable';

export const moveHandler = (
  content: Immutable.List<ResourceContent>,
  onEditContentList: (content: Immutable.List<ResourceContent>) => void,
  editorMap: ActivityEditorMap,
  activities: Immutable.Map<string, Activity>,
  setAssisstive: (s: string) => void,
) => (index: number, up: boolean) => {
  if (index === 0 && up) return;

  const item = content.get(index) as ResourceContent;
  const inserted = content.remove(index).insert(index + (up ? -1 : 1), item as any);

  onEditContentList(inserted);

  const newIndex = inserted.findIndex((c) => c.id === item.id);
  const desc = item.type === 'content' ? 'Content' : getFriendlyName(item, editorMap, activities);

  setAssisstive(`Listbox. ${newIndex + 1} of ${content.size}. ${desc}.`);
};
