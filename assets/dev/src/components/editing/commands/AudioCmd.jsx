import React from 'react';
import { Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { audio } from 'data/content/model/elements/factories';
const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c) => window.oliDispatch(modalActions.display(c));
export function selectAudio(projectSlug, model) {
    return new Promise((resolve, _reject) => {
        const selected = { audio: null };
        const mediaLibrary = (<ModalSelection title="Embed audio" onInsert={() => {
                dismiss();
                if (selected.audio)
                    resolve(selected.audio);
            }} onCancel={() => dismiss()} disableInsert={true}>
        <MediaManager projectSlug={projectSlug} onEdit={() => { }} mimeFilter={MIMETYPE_FILTERS.AUDIO} selectionType={SELECTION_TYPES.SINGLE} initialSelectionPaths={[model.src]} onSelectionChange={(audios) => {
                selected.audio = audio(audios[0].url);
            }}/>
      </ModalSelection>);
        display(mediaLibrary);
    });
}
const libraryCommand = {
    execute: (context, editor) => {
        const at = editor.selection;
        selectAudio(context.projectSlug, audio()).then((audio) => Transforms.insertNodes(editor, audio, { at }));
    },
    precondition: (_editor) => {
        return true;
    },
};
function createCustomEventCommand(onRequestMedia) {
    const customEventCommand = {
        execute: (_context, editor) => {
            const at = editor.selection;
            if (!at)
                return;
            const request = {
                type: 'MediaItemRequest',
                mimeTypes: MIMETYPE_FILTERS.AUDIO,
            };
            onRequestMedia(request).then((r) => {
                if (typeof r === 'string') {
                    Transforms.insertNodes(editor, audio(r), { at });
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
        icon: () => 'audiotrack',
        description: () => 'Audio Clip',
        command: onRequestMedia === null || onRequestMedia === undefined
            ? libraryCommand
            : createCustomEventCommand(onRequestMedia),
    };
    return commandDesc;
}
//# sourceMappingURL=AudioCmd.jsx.map