import * as React from 'react';
import { Transforms } from 'slate';
import { modalActions } from 'actions/modal';
import ModalSelection from 'components/modal/ModalSelection';
import { useState } from 'react';
import * as Settings from 'components/editing/models/settings/Settings';
import { webpage } from 'data/content/model/elements/factories';
const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c) => window.oliDispatch(modalActions.display(c));
const WebpageCreation = (props) => {
    const [src, setSrc] = useState('');
    return (<div>
      <div className="form">
        <label>Enter the webpage URL:</label>
        <input type="text" value={src} onChange={(e) => {
            props.onChange(e.target.value);
            setSrc(e.target.value);
        }} onKeyPress={(e) => Settings.onEnterApply(e, () => props.onEdit(src))} className="form-control mr-sm-2"/>
        <div className="mb-2">
          <small>e.g. https://www.wikipedia.org</small>
        </div>
      </div>
    </div>);
};
export function selectWebpage() {
    return new Promise((resolve, _reject) => {
        const selected = { src: null };
        const mediaLibrary = (<ModalSelection title="Insert Webpage" onInsert={() => {
                dismiss();
                resolve(selected.src ? selected.src : '');
            }} onCancel={() => dismiss()}>
        <WebpageCreation onEdit={(src) => {
                dismiss();
                resolve(src);
            }} onChange={(src) => {
                selected.src = src;
            }}/>
      </ModalSelection>);
        display(mediaLibrary);
    });
}
const command = {
    execute: (_context, editor) => {
        const at = editor.selection;
        if (!at)
            return;
        selectWebpage().then((selectedSrc) => {
            if (selectedSrc !== null) {
                let src = selectedSrc;
                if (!src.startsWith('http://') && !src.startsWith('https://')) {
                    src = 'https://' + src;
                }
                Transforms.insertNodes(editor, webpage(src), { at });
            }
        });
    },
    precondition: (_editor) => {
        return true;
    },
};
export const commandDesc = {
    type: 'CommandDesc',
    icon: () => 'public',
    description: () => 'Webpage',
    command,
};
//# sourceMappingURL=WebpageCmd.jsx.map