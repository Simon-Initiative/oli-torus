import guid from 'utils/guid';
export var ResourceType;
(function (ResourceType) {
    ResourceType[ResourceType["page"] = 0] = "page";
    ResourceType[ResourceType["assessment"] = 1] = "assessment";
})(ResourceType || (ResourceType = {}));
export const ActivityPurposes = [
    { value: 'none', label: 'Activity' },
    { value: 'checkpoint', label: 'Checkpoint' },
    { value: 'didigetthis', label: 'Did I get this?' },
    { value: 'learnbydoing', label: 'Learn by doing' },
];
export const ContentPurposes = [
    { value: 'none', label: 'Content' },
    { value: 'example', label: 'Example' },
    { value: 'learnmore', label: 'Learn more' },
    { value: 'manystudentswonder', label: 'Many students wonder' },
];
export const createDefaultStructuredContent = () => {
    return {
        type: 'content',
        id: guid(),
        children: [{ type: 'p', id: guid(), children: [{ text: '' }] }],
        purpose: 'none',
    };
};
export const createDefaultSelection = () => {
    return {
        type: 'selection',
        id: guid(),
        count: 1,
        logic: { conditions: null },
        purpose: 'none',
    };
};
//# sourceMappingURL=resource.js.map