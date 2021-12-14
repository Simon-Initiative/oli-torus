import React from 'react';
import { Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { image } from 'data/content/model/elements/factories';
const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c) => window.oliDispatch(modalActions.display(c));
export function selectImage(projectSlug, _selectedUrl) {
    return new Promise((resolve, _reject) => {
        let selectedUrl = undefined;
        const mediaLibrary = (<ModalSelection title="Select Image" size={sizes.extraLarge} onInsert={() => {
                dismiss();
                resolve(selectedUrl);
            }} onCancel={() => dismiss()} disableInsert={true} okLabel="Select">
        <UrlOrUpload onUrlChange={(url) => (selectedUrl = url)} onMediaSelectionChange={(mediaOrUrl) => { var _a; return (selectedUrl = (_a = mediaOrUrl[0]) === null || _a === void 0 ? void 0 : _a.url); }} projectSlug={projectSlug} onEdit={() => { }} mimeFilter={MIMETYPE_FILTERS.IMAGE} selectionType={SELECTION_TYPES.SINGLE} initialSelectionPaths={selectedUrl ? [selectedUrl] : []}/>
      </ModalSelection>);
        display(mediaLibrary);
    });
}
const libraryCommand = {
    execute: (context, editor) => {
        const at = editor.selection;
        selectImage(context.projectSlug, undefined).then((src) => Transforms.insertNodes(editor, image(src), at ? { at } : undefined));
    },
    precondition: (_editor) => {
        return true;
    },
};
function createCustomEventCommand(onRequestMedia) {
    const customEventCommand = {
        execute: (context, editor) => {
            const at = editor.selection;
            const request = {
                type: 'MediaItemRequest',
                mimeTypes: MIMETYPE_FILTERS.IMAGE,
            };
            onRequestMedia(request).then((r) => {
                if (typeof r === 'string') {
                    Transforms.insertNodes(editor, image(r), at ? { at } : undefined);
                }
            });
        },
        precondition: (_editor) => {
            return true;
        },
    };
    return customEventCommand;
}
export function getCommand(onRequestMedia) {
    const commandDesc = {
        type: 'CommandDesc',
        icon: () => 'image',
        description: () => 'Image',
        command: onRequestMedia === null || onRequestMedia === undefined
            ? libraryCommand
            : createCustomEventCommand(onRequestMedia),
    };
    return commandDesc;
}
//# sourceMappingURL=ImageCmd.jsx.map