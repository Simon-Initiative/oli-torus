import { getContentDescription } from 'data/content/utils';
export const focusHandler = (setAssistive, content, editorMap, activities) => (key) => {
    var _a;
    const item = content.get(key);
    const desc = item.type === 'content'
        ? getContentDescription(item)
        : (_a = activities.get(item.activitySlug)) === null || _a === void 0 ? void 0 : _a.friendlyName;
    const index = content.keySeq().findIndex((k) => k === key);
    setAssistive(`Listbox. ${index + 1} of ${content.size}. ${desc}.`);
};
//# sourceMappingURL=focus.js.map