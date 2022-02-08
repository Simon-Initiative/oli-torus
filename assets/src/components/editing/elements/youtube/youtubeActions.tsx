import { Transforms } from 'slate';
import { getQueryVariableFromString } from 'utils/params';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import React, { useState } from 'react';
import { modalActions } from 'actions/modal';
import ModalSelection from 'components/modal/ModalSelection';
import { onEnterApply } from 'components/editing/elements/common/settings/Settings';

export const insertYoutube = createButtonCommandDesc({
  icon: 'play_circle_filled',
  description: 'YouTube',
  execute: (_context, editor, _params) => {
    const at = editor.selection;
    if (!at) return;

    selectYoutube().then((selectedSrc) => {
      if (selectedSrc !== null) {
        let src = selectedSrc;

        const hasParams = src.includes('?');

        if (hasParams) {
          const queryString = src.substr(src.indexOf('?') + 1);
          src = getQueryVariableFromString('v', queryString);
        } else if (src.indexOf('/youtu.be/') !== -1) {
          src = src.substr(src.lastIndexOf('/') + 1);
        }

        Transforms.insertNodes(editor, Model.youtube(src), { at });
      }
    });
  },
});

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export type YoutubeCreationProps = {
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
          onKeyPress={(e) => onEnterApply(e, () => props.onEdit(src))}
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

    const selection = (
      <ModalSelection
        title="Insert Webpage"
        onInsert={() => {
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
      </ModalSelection>
    );

    display(selection);
  });
}
