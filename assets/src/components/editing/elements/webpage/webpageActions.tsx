import * as React from 'react';
import { Transforms } from 'slate';
import { modalActions } from 'actions/modal';
import { Modal } from 'components/modal/Modal';
import { useState } from 'react';
import { Model } from 'data/content/model/elements/factories';
import * as Settings from 'components/editing/elements/common/settings/Settings';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export type WebpageCreationProps = {
  onChange: (src: string) => void;
  onEdit: (src: string) => void;
};
const WebpageCreation = (props: WebpageCreationProps) => {
  const [src, setSrc] = useState('');

  return (
    <div>
      <div className="form">
        <label>Enter the webpage URL:</label>
        <input
          type="text"
          value={src}
          onChange={(e) => {
            props.onChange(e.target.value);
            setSrc(e.target.value);
          }}
          onKeyPress={(e: any) => Settings.onEnterApply(e, () => props.onEdit(src))}
          className="form-control mr-sm-2"
        />
        <div className="mb-2">
          <small>e.g. https://www.wikipedia.org</small>
        </div>
      </div>
    </div>
  );
};

export function selectWebpage(): Promise<string | null> {
  return new Promise((resolve, _reject) => {
    const selected: { src: null | string } = { src: null };

    const mediaLibrary = (
      <Modal
        title="Insert Webpage"
        onOk={() => {
          dismiss();
          resolve(selected.src ? selected.src : '');
        }}
        onCancel={() => dismiss()}
      >
        <WebpageCreation
          onEdit={(src: string) => {
            dismiss();
            resolve(src);
          }}
          onChange={(src: string) => {
            selected.src = src;
          }}
        />
      </Modal>
    );

    display(mediaLibrary);
  });
}

export const insertWebpage = createButtonCommandDesc({
  icon: <i className="fa-solid fa-globe"></i>,
  description: 'Webpage',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    selectWebpage().then((selectedSrc) => {
      if (selectedSrc !== null) {
        let src = selectedSrc;
        if (!src.startsWith('http://') && !src.startsWith('https://')) {
          src = 'https://' + src;
        }

        Transforms.insertNodes(editor, Model.webpage(src), { at });
      }
    });
  },
});
