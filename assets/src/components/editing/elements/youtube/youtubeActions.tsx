import { Transforms } from 'slate';
import { getQueryVariableFromString } from 'utils/params';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import React, { useState } from 'react';
import { modalActions } from 'actions/modal';
import { Modal } from 'components/modal/Modal';
import { onEnterApply } from 'components/editing/elements/common/settings/Settings';

export const youtubeUrlToId = (src?: string | null) => {
  if (!src) return null;

  // https://www.youtube.com/embed/W98qXD35kXY
  const embedRegex = /embed\/([a-zA-Z0-9_-]+)/;
  const match = embedRegex.exec(src);
  if (match) {
    return match[1];
  }

  const hasParams = src.includes('?');
  if (hasParams) {
    const queryString = src.substr(src.indexOf('?') + 1);
    src = getQueryVariableFromString('v', queryString);
  } else if (src.indexOf('/youtu.be/') !== -1) {
    src = src.substr(src.lastIndexOf('/') + 1);
  }

  return src;
};

export const insertYoutube = createButtonCommandDesc({
  icon: <i className="fa-brands fa-youtube"></i>,
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
