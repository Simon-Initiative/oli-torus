import { ActivityReference, ResourceContent } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getFriendlyName } from '../utils';
import { ActivityEditContext } from 'data/content/activity';
import * as Immutable from 'immutable';

export const moveHandler =
  (
    content: Immutable.OrderedMap<string, ResourceContent>,
    onEditContentList: (content: Immutable.OrderedMap<string, ResourceContent>) => void,
    editorMap: ActivityEditorMap,
    activities: Immutable.Map<string, ActivityEditContext>,
    setAssistive: (s: string) => void,
  ) =>
  (key: string, up: boolean) => {
    if (content.first<ResourceContent>().id === key && up) return;

    const item = content.get(key) as ResourceContent;
    const index = content.keySeq().indexOf(key);

    const prefix = content.delete(key).take(index + (up ? -1 : 1));
    const suffix = content.delete(key).skip(index + (up ? -1 : 1));

    const inserted = prefix.concat([[key, item]]).concat(suffix);

    onEditContentList(inserted);

    const newIndex = inserted.keySeq().findIndex((k) => k === key);
    const desc =
      item.type === 'content'
        ? 'Content'
        : getFriendlyName(item as ActivityReference, editorMap, activities);

    setAssistive(`Listbox. ${newIndex + 1} of ${content.size}. ${desc}.`);
  };
