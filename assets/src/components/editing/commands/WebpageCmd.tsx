import { CommandDesc, Command } from 'components/editing/commands/interfaces';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { modalActions } from 'actions/modal';
import ModalSelection from 'components/modal/ModalSelection';
import { useState } from 'react';
import * as Settings from 'components/editing/models/settings/Settings';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

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
          onKeyPress={(e) => Settings.onEnterApply(e, () => props.onEdit(src))}
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
  return new Promise((resolve, reject) => {
    const selected = { src: null };

    const mediaLibrary = (
      <ModalSelection
        title="Insert Webpage"
        onInsert={() => {
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
            selected.src = src as any;
          }}
        />
      </ModalSelection>
    );

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor) => {
    const at = editor.selection as any;

    selectWebpage().then((selectedSrc) => {
      if (selectedSrc !== null) {
        let src = selectedSrc;
        if (!src.startsWith('http://') && !src.startsWith('https://')) {
          src = 'https://' + src;
        }

        Transforms.insertNodes(editor, ContentModel.webpage(src), { at });
      }
    });
  },
  precondition: (editor) => {
    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'public',
  description: () => 'Webpage',
  command,
};
