export const getFriendlyName = (item, editorMap, activities) => {
    const activity = activities.get(item.activitySlug);
    return editorMap[activity.typeSlug].friendlyName;
};
export const getDragPayload = (contentItem, activities, projectSlug) => {
    if (contentItem.type === 'content') {
        return contentItem;
    }
    if (activities.has(contentItem.activitySlug)) {
        const activity = activities.get(contentItem.activitySlug);
        return {
            type: 'ActivityPayload',
            id: contentItem.id,
            reference: contentItem,
            activity: activity,
            project: projectSlug,
        };
    }
    return {
        type: 'UnknownPayload',
        data: contentItem,
        id: contentItem.id,
    };
};
//# sourceMappingURL=utils.js.map