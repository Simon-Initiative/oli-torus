import React, { useState } from 'react';
import { Transforms } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { onEnterApply } from 'components/editing/elements/common/settings/Settings';
import { Modal } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { Model } from 'data/content/model/elements/factories';
import { getQueryVariableFromString } from 'utils/params';

export const youtubeUrlToId = (src?: string | null) => {
  if (!src) return null;

  // check for query string including a v param
  // e.g. http://youtube.com/watch?v=W98qXD35kXY&list=x8wefc
  const [urlBase, queryString] = src.split('?');
  if (queryString) {
    const vParam = getQueryVariableFromString('v', queryString);
    if (vParam !== '') return vParam;
  }

  // else examine urlBase = url w/any query string stripped

  // embed url form https://www.youtube.com/embed/W98qXD35kXY
  const embedRegex = /embed\/([a-zA-Z0-9_-]+)/;
  const match = embedRegex.exec(urlBase);
  if (match) {
    return match[1];
  }

  // short url form https://youtu.be/W98qXD35kXY
  if (urlBase.indexOf('/youtu.be/') !== -1) {
    return urlBase.substr(src.lastIndexOf('/') + 1);
  }

  // else treat as bare video id
  return src;
};

export const insertYoutube = createButtonCommandDesc({
  icon: <i className="fa-brands fa-youtube"></i>,
  category: 'Media',
  description: 'YouTube',
  execute: (_context, editor, _params) => {
    const at = editor.selection;
    if (!at) return;

    selectYoutube()
      .then(youtubeUrlToId)
      .then((src) => {
        src && Transforms.insertNodes(editor, Model.youtube(src), { at });
      });
  },
});

type YoutubeCreationProps = {
  onChange: (src: string) => void;
  onEdit: (src: string) => void;
};
const YoutubeCreation = (props: YoutubeCreationProps) => {
  const [src, setSrc] = useState('');

  return (
    <div>
      <div className="form">
        <label>Enter the YouTube URL or video ID:</label>
        <input
          type="text"
          value={src}
          onChange={(e) => {
            props.onChange(e.target.value);
            setSrc(e.target.value);
          }}
          onKeyPress={(e: any) => onEnterApply(e, () => props.onEdit(src))}
          className="form-control mr-sm-2"
        />
        <div className="mb-2">
          <small>e.g. https://www.youtube.com/watch?v=zHIIzcWqsP0</small>
        </div>
      </div>
    </div>
  );
};

export function selectYoutube(): Promise<string | null> {
  return new Promise((resolve, _reject) => {
    const selected: { src: null | string } = { src: null };
    const dismiss = () => window.oliDispatch(modalActions.dismiss());
    const display = (c: any) => window.oliDispatch(modalActions.display(c));

    const selection = (
      <Modal
        title="Insert YouTube"
        onOk={() => {
          dismiss();
          resolve(selected.src ? selected.src : '');
        }}
        onCancel={() => dismiss()}
      >
        <YoutubeCreation
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

    display(selection);
  });
}
