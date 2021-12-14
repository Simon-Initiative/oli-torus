import { getFriendlyName } from '../utils';
export const moveHandler = (content, onEditContentList, editorMap, activities, setAssistive) => (key, up) => {
    if (content.first().id === key && up)
        return;
    const item = content.get(key);
    const index = content.keySeq().indexOf(key);
    const prefix = content.delete(key).take(index + (up ? -1 : 1));
    const suffix = content.delete(key).skip(index + (up ? -1 : 1));
    const inserted = prefix.concat([[key, item]]).concat(suffix);
    onEditContentList(inserted);
    const newIndex = inserted.keySeq().findIndex((k) => k === key);
    const desc = item.type === 'content'
        ? 'Content'
        : getFriendlyName(item, editorMap, activities);
    setAssistive(`Listbox. ${newIndex + 1} of ${content.size}. ${desc}.`);
};
//# sourceMappingURL=move.js.map