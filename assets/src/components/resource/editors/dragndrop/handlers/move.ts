import { ActivityReference, ResourceContent } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getFriendlyName } from '../utils';
import { ActivityEditContext } from 'data/content/activity';
import * as Immutable from 'immutable';
import { PageEditorContent } from 'data/editor/PageEditorContent';

function determineIndex(index: number[], up: boolean) {
  const lastIndex = index[index.length - 1];

  const updatedLastIndex = up ? Math.min(9, lastIndex + 1) : Math.max(0, lastIndex - 1);

  return index.splice(index.length - 1, 1, updatedLastIndex);
}

export const moveHandler =
  (
    content: PageEditorContent,
    onEditContent: (content: PageEditorContent) => void,
    editorMap: ActivityEditorMap,
    activities: Immutable.Map<string, ActivityEditContext>,
    setAssistive: (s: string) => void,
  ) =>
  (key: string, up: boolean) => {
    if (content.first().id === key && up) return;

    const item = content.find(key) as ResourceContent;
    const index = content.findIndex((c) => c.id === key);

    const inserted = content.delete(key).insertAt(determineIndex(index, up), item);

    onEditContent(inserted);

    const newFlattenedIndex = inserted.flattenedIndex(key);
    const desc =
      item.type === 'content'
        ? 'Content'
        : getFriendlyName(item as ActivityReference, editorMap, activities);

    setAssistive(`Listbox. ${newFlattenedIndex + 1} of ${content.count()}. ${desc}.`);
  };
