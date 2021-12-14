import { toSimpleText } from 'components/editing/utils';
export const dragStartHandler = (dragPayload, contentItem, setActiveDragId) => (e, id) => {
    const dt = e.dataTransfer;
    // Enables dragging of the underlying JSON of nodes into VSCode for
    // debugging / troubleshooting purposes
    const resource = JSON.stringify([
        {
            resource: '' + contentItem.id,
            content: JSON.stringify(dragPayload, null, 2),
            viewState: null,
            encoding: 'UTF-8',
            mode: null,
            isExternal: false,
        },
    ]);
    dt.setData('CodeEditors', resource);
    dt.setData('application/x-oli-resource-content', JSON.stringify(dragPayload));
    dt.setData('text/html', toSimpleText(contentItem));
    dt.setData('text/plain', toSimpleText(contentItem));
    const imageId = document.getElementById(id);
    if (imageId) {
        dt.setDragImage(imageId, 0, 0);
    }
    dt.effectAllowed = 'move';
    // setting the reorder mode flag needs to happen at the end of the event loop to
    // ensure that all dom nodes that existed when the drag began still exist throughout
    // the entire event. This set timeout ensures this correct order of operations
    setTimeout(() => {
        setActiveDragId(contentItem.id);
    });
};
//# sourceMappingURL=dragStart.js.map